from datetime import date, timedelta
from typing import Any

from supabase import Client, create_client

from app.config import settings
from app.schemas.receipt import SaveReceiptRequest, UpdateProductRequest

FINAL_PRODUCT_STATUSES = {"consumed", "wasted", "expired", "deleted"}
EDITABLE_PRODUCT_FIELDS = {
    "name",
    "normalized_name",
    "category",
    "quantity",
    "unit",
    "storage_location",
    "purchase_date",
    "estimated_expiry_date",
    "expiry_confidence",
    "price",
    "notes",
}


def _normalize_supabase_url(url: str) -> str:
    """Return the project base URL expected by supabase-py."""
    cleaned = url.strip().rstrip("/")
    for suffix in ("/rest/v1", "/auth/v1", "/storage/v1", "/functions/v1"):
        if cleaned.endswith(suffix):
            cleaned = cleaned[: -len(suffix)]
    return cleaned


def get_supabase_client() -> Client:
    if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
        raise RuntimeError("Supabase is not configured. Check SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY")

    supabase_url = _normalize_supabase_url(settings.SUPABASE_URL)
    return create_client(supabase_url, settings.SUPABASE_SERVICE_ROLE_KEY)


def _estimate_expiry_date_from_added_date(days: int | None) -> str | None:
    if days is None:
        return None
    return (date.today() + timedelta(days=days)).isoformat()


def save_receipt_with_products(payload: SaveReceiptRequest) -> dict[str, Any]:
    supabase = get_supabase_client()

    saved_products_total = sum((product.price or 0) for product in payload.products)
    receipt_insert = {
        "user_id": payload.user_id,
        "store_name": payload.store.name,
        "purchase_date": payload.store.purchase_date,
        "total_amount": saved_products_total if saved_products_total else payload.store.total_amount,
        "ai_response": payload.raw_ai_response or payload.model_dump(),
    }

    receipt_result = supabase.table("receipts").insert(receipt_insert).execute()
    if not receipt_result.data:
        raise RuntimeError("Could not insert receipt")

    receipt = receipt_result.data[0]
    receipt_id = receipt["id"]

    product_rows = []
    event_rows = []
    added_date = date.today().isoformat()
    for product in payload.products:
        estimated_expiry_date = _estimate_expiry_date_from_added_date(product.estimated_expiry_days)
        product_rows.append(
            {
                "user_id": payload.user_id,
                "receipt_id": receipt_id,
                "name": product.name,
                "normalized_name": product.normalized_name,
                "category": product.category,
                "quantity": product.quantity,
                "unit": product.unit,
                "storage_location": product.storage_location,
                "purchase_date": added_date,
                "estimated_expiry_date": estimated_expiry_date,
                "expiry_confidence": product.expiry_confidence,
                "price": product.price,
                "status": "active",
                "notes": product.notes,
            }
        )

    products_saved = 0
    if product_rows:
        products_result = supabase.table("products").insert(product_rows).execute()
        products_saved = len(products_result.data or [])
        for saved_product in products_result.data or []:
            event_rows.append(
                {
                    "user_id": payload.user_id,
                    "product_id": saved_product["id"],
                    "event_type": "created",
                    "metadata": {"source": "receipt_scan", "receipt_id": receipt_id},
                }
            )

    if event_rows:
        supabase.table("product_events").insert(event_rows).execute()

    return {"receipt_id": receipt_id, "products_saved": products_saved}


def list_products_for_user(user_id: str, status: str | None = None) -> list[dict[str, Any]]:
    supabase = get_supabase_client()
    query = supabase.table("products").select("*").eq("user_id", user_id).neq("status", "deleted").order("estimated_expiry_date")

    if status:
        query = query.eq("status", status)

    result = query.execute()
    return result.data or []


def get_product_for_user(product_id: str, user_id: str) -> dict[str, Any]:
    supabase = get_supabase_client()
    result = (
        supabase.table("products")
        .select("*")
        .eq("id", product_id)
        .eq("user_id", user_id)
        .neq("status", "deleted")
        .limit(1)
        .execute()
    )

    if not result.data:
        raise RuntimeError("Product not found")

    return result.data[0]


def update_product_for_user(product_id: str, user_id: str, payload: UpdateProductRequest) -> dict[str, Any]:
    supabase = get_supabase_client()
    current_product = get_product_for_user(product_id=product_id, user_id=user_id)

    if current_product.get("status") in FINAL_PRODUCT_STATUSES:
        raise RuntimeError(f"Product cannot be edited because it has final status: {current_product.get('status')}")

    update_data = payload.model_dump(exclude_unset=True)
    update_data = {key: value for key, value in update_data.items() if key in EDITABLE_PRODUCT_FIELDS}

    if not update_data:
        raise RuntimeError("No valid fields to update")

    result = (
        supabase.table("products")
        .update(update_data)
        .eq("id", product_id)
        .eq("user_id", user_id)
        .eq("status", "active")
        .execute()
    )

    if not result.data:
        raise RuntimeError("Product not updated")

    supabase.table("product_events").insert(
        {
            "user_id": user_id,
            "product_id": product_id,
            "event_type": "edited",
            "metadata": {"source": "api", "changes": update_data},
        }
    ).execute()

    return result.data[0]


def mark_product_status(product_id: str, user_id: str, status: str, event_type: str) -> dict[str, Any]:
    supabase = get_supabase_client()

    current_result = (
        supabase.table("products")
        .select("id,status")
        .eq("id", product_id)
        .eq("user_id", user_id)
        .neq("status", "deleted")
        .limit(1)
        .execute()
    )

    if not current_result.data:
        raise RuntimeError("Product not found")

    current_status = current_result.data[0].get("status")
    if current_status in FINAL_PRODUCT_STATUSES:
        raise RuntimeError(f"Product already has final status: {current_status}")

    if status not in FINAL_PRODUCT_STATUSES:
        raise RuntimeError(f"Invalid final status: {status}")

    result = (
        supabase.table("products")
        .update({"status": status})
        .eq("id", product_id)
        .eq("user_id", user_id)
        .eq("status", "active")
        .execute()
    )

    if not result.data:
        raise RuntimeError("Product not updated because it is not active")

    supabase.table("product_events").insert(
        {
            "user_id": user_id,
            "product_id": product_id,
            "event_type": event_type,
            "metadata": {"source": "api", "previous_status": current_status, "new_status": status},
        }
    ).execute()

    return result.data[0]


def delete_product_for_user(product_id: str, user_id: str) -> dict[str, Any]:
    return mark_product_status(product_id=product_id, user_id=user_id, status="deleted", event_type="deleted")


def get_stats_summary_for_user(user_id: str) -> dict[str, Any]:
    products = list_products_for_user(user_id=user_id)
    active_products = [product for product in products if product.get("status") == "active"]
    consumed_products = [product for product in products if product.get("status") == "consumed"]
    wasted_products = [product for product in products if product.get("status") == "wasted"]
    expired_products = [product for product in products if product.get("status") == "expired"]

    total_final = len(consumed_products) + len(wasted_products) + len(expired_products)
    usage_percentage = round((len(consumed_products) / total_final) * 100) if total_final else 0

    today = date.today()
    expiring_soon = []
    expired_active = []
    for product in active_products:
        expiry_date_value = product.get("estimated_expiry_date")
        if not expiry_date_value:
            continue
        expiry_date = date.fromisoformat(expiry_date_value)
        days_left = (expiry_date - today).days
        if days_left < 0:
            expired_active.append(product)
        elif days_left <= 2:
            expiring_soon.append(product)

    saved_value = sum((product.get("price") or 0) for product in consumed_products)
    wasted_value = sum((product.get("price") or 0) for product in wasted_products + expired_products)
    score = len(consumed_products) * 10 - (len(wasted_products) + len(expired_products)) * 5
    if score < 0:
        score = 0

    return {
        "active_count": len(active_products),
        "consumed_count": len(consumed_products),
        "wasted_count": len(wasted_products),
        "expired_count": len(expired_products),
        "expiring_soon_count": len(expiring_soon),
        "expired_active_count": len(expired_active),
        "usage_percentage": usage_percentage,
        "estimated_savings": round(float(saved_value), 2),
        "estimated_waste": round(float(wasted_value), 2),
        "current_streak": 0,
        "score": score,
        "level": "Nevera en control" if usage_percentage >= 80 else "Aprendiz anti-desperdicio",
    }
