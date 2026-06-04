from datetime import date, timedelta
from typing import Any

from supabase import Client, create_client

from app.config import settings
from app.schemas.receipt import SaveReceiptRequest


def _normalize_supabase_url(url: str) -> str:
    """Return the project base URL expected by supabase-py.

    Supabase client expects: https://PROJECT_REF.supabase.co
    It should not include /rest/v1, /auth/v1, /storage/v1, etc.
    """
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


def _safe_purchase_date(value: str | None) -> str:
    if value:
        return value
    return date.today().isoformat()


def _estimate_expiry_date(purchase_date: str | None, days: int | None) -> str | None:
    if days is None:
        return None
    base_date = date.fromisoformat(_safe_purchase_date(purchase_date))
    return (base_date + timedelta(days=days)).isoformat()


def save_receipt_with_products(payload: SaveReceiptRequest) -> dict[str, Any]:
    supabase = get_supabase_client()

    receipt_insert = {
        "user_id": payload.user_id,
        "store_name": payload.store.name,
        "purchase_date": payload.store.purchase_date,
        "total_amount": payload.store.total_amount,
        "ai_response": payload.raw_ai_response or payload.model_dump(),
    }

    receipt_result = supabase.table("receipts").insert(receipt_insert).execute()
    if not receipt_result.data:
        raise RuntimeError("Could not insert receipt")

    receipt = receipt_result.data[0]
    receipt_id = receipt["id"]

    product_rows = []
    event_rows = []
    for product in payload.products:
        estimated_expiry_date = _estimate_expiry_date(
            payload.store.purchase_date,
            product.estimated_expiry_days,
        )
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
                "purchase_date": _safe_purchase_date(payload.store.purchase_date),
                "estimated_expiry_date": estimated_expiry_date,
                "expiry_confidence": product.expiry_confidence,
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
    query = supabase.table("products").select("*").eq("user_id", user_id).order("estimated_expiry_date")

    if status:
        query = query.eq("status", status)

    result = query.execute()
    return result.data or []


def mark_product_status(product_id: str, user_id: str, status: str, event_type: str) -> dict[str, Any]:
    supabase = get_supabase_client()

    update_result = (
        supabase.table("products")
        .update({"status": status})
        .eq("id", product_id)
        .eq("user_id", user_id)
        .execute()
    )

    if not update_result.data:
        raise RuntimeError("Product not found or not updated")

    supabase.table("product_events").insert(
        {
            "user_id": user_id,
            "product_id": product_id,
            "event_type": event_type,
            "metadata": {"source": "api"},
        }
    ).execute()

    return update_result.data[0]
