import calendar
import json
import re
from datetime import date, datetime, timedelta
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from supabase import Client, create_client

from app.config import settings
from app.schemas.receipt import BarcodeProductLookup, SaveReceiptRequest, UpdateProductRequest

FINAL_PRODUCT_STATUSES = {"consumed", "wasted", "expired", "deleted"}
EDITABLE_PRODUCT_FIELDS = {
    "name",
    "normalized_name",
    "barcode",
    "category",
    "quantity",
    "unit",
    "storage_location",
    "purchase_date",
    "estimated_expiry_date",
    "expiry_confidence",
    "price",
    "image_url",
    "notes",
}

PRODUCT_OPTIONAL_COLUMN_FIELDS = {"barcode", "image_url"}
BARCODE_CACHE_TABLE = "barcode_products"
BARCODE_CACHE_OPTIONAL_FIELDS = {
    "original_image_url",
    "processed_image_url",
    "image_storage_path",
    "image_processing_status",
    "provider_source",
    "is_verified",
    "verified_by",
    "verified_at",
    "confidence_score",
    "last_lookup_at",
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


def get_auth_email_status(email: str) -> dict[str, bool]:
    normalized_email = email.strip().lower()
    if not normalized_email:
        return {"exists": False, "confirmed": False}

    try:
        users = get_supabase_client().auth.admin.list_users()
    except Exception:
        return {"exists": False, "confirmed": False}

    for user in users:
        user_email = (getattr(user, "email", None) or "").strip().lower()
        if user_email != normalized_email:
            continue

        confirmed = bool(
            getattr(user, "email_confirmed_at", None)
            or getattr(user, "confirmed_at", None)
        )
        return {"exists": True, "confirmed": confirmed}

    return {"exists": False, "confirmed": False}


def _estimate_expiry_date_from_added_date(days: int | None) -> str | None:
    if days is None:
        return None
    return (date.today() + timedelta(days=days)).isoformat()


def _clean_product_name(value: str | None) -> str:
    name = (value or "Producto").strip()
    replacements = [
        (r"\b\d+\s*[xX]\s*\d+([,.]\d+)?\s*(g|kg|ml|l|u|ud|uds|unidades|pcs)?\b", ""),
        (r"\b\d+([,.]\d+)?\s*(g|kg|ml|l|u|ud|uds|unidades|pcs)\b", ""),
        (r"\bpack\s*\d+\b", ""),
        (r"\b\d+\s*pack\b", ""),
        (r"\b\d+\s*(lonchas|filetes|piezas|unidades)\b", ""),
    ]
    for pattern, replacement in replacements:
        name = re.sub(pattern, replacement, name, flags=re.IGNORECASE)
    name = re.sub(r"\s+", " ", name)
    name = re.sub(r"[\-·,]+$", "", name).strip()
    return name or (value or "Producto").strip() or "Producto"


def _insert_products_with_price_fallback(supabase: Client, product_rows: list[dict[str, Any]]):
    """Insert products and tolerate projects that have not run optional migrations yet."""
    try:
        return supabase.table("products").insert(product_rows).execute()
    except Exception as exc:
        message = str(exc)
        missing_field = _optional_schema_field_from_error(message)
        if not missing_field:
            raise

        fallback_rows = []
        for row in product_rows:
            clean_row = dict(row)
            clean_row.pop(missing_field, None)
            fallback_rows.append(clean_row)
        return _insert_products_with_price_fallback(supabase, fallback_rows)


def _optional_schema_field_from_error(message: str) -> str | None:
    if "schema cache" not in message:
        return None
    for field in {"price", *PRODUCT_OPTIONAL_COLUMN_FIELDS}:
        if field in message:
            return field
    return None


def _product_notes_payload(product) -> str | None:
    metadata = {
        key: value
        for key, value in {
            "barcode": product.barcode,
            "image_url": product.image_url,
        }.items()
        if value
    }
    if not metadata:
        return product.notes

    payload = {
        "_frigocheck": metadata,
        "text": product.notes,
    }
    return json.dumps(payload, ensure_ascii=False)


def get_cached_barcode_product(barcode: str) -> BarcodeProductLookup | None:
    if not barcode:
        return None

    supabase = get_supabase_client()
    try:
        result = (
            supabase.table(BARCODE_CACHE_TABLE)
            .select("*")
            .eq("barcode", barcode)
            .limit(1)
            .execute()
        )
    except Exception:
        return None

    if not result.data:
        return None

    row = result.data[0]
    row = _refresh_cached_image_if_needed(row)
    image_url = row.get("processed_image_url") or row.get("image_url")
    source = row.get("source") or row.get("provider_source") or "frigocheck_cache"
    return BarcodeProductLookup(
        barcode=row.get("barcode") or barcode,
        found=True,
        name=row.get("name"),
        normalized_name=row.get("normalized_name"),
        brand=row.get("brand"),
        category=row.get("category"),
        quantity=row.get("quantity"),
        unit=row.get("unit"),
        storage_location=row.get("storage_location"),
        estimated_expiry_days=row.get("estimated_expiry_days"),
        expiry_confidence=row.get("expiry_confidence") or "medium",
        image_url=image_url,
        source=source,
    )


def find_cached_product_for_name(name: str | None) -> BarcodeProductLookup | None:
    clean_name = _clean_product_name(name)
    if not clean_name or clean_name.lower() == "producto":
        return None

    tokens = _meaningful_name_tokens(clean_name)
    if not tokens:
        return None

    supabase = get_supabase_client()
    try:
        result = (
            supabase.table(BARCODE_CACHE_TABLE)
            .select("*")
            .limit(30)
            .execute()
        )
    except Exception:
        return None

    best_row = None
    best_score = 0.0
    for row in result.data or []:
        row_name = row.get("normalized_name") or row.get("name")
        row_tokens = _meaningful_name_tokens(row_name)
        if not row_tokens:
            continue
        score = len(tokens & row_tokens) / max(len(tokens | row_tokens), 1)
        if row.get("is_verified"):
            score += 0.15
        if score > best_score:
            best_score = score
            best_row = row

    if best_row is None or best_score < 0.50:
        return None

    best_row = _refresh_cached_image_if_needed(best_row)
    image_url = best_row.get("processed_image_url") or best_row.get("image_url")
    source = best_row.get("source") or best_row.get("provider_source") or "frigocheck_cache"
    return BarcodeProductLookup(
        barcode=best_row.get("barcode") or "",
        found=True,
        name=best_row.get("name"),
        normalized_name=best_row.get("normalized_name"),
        brand=best_row.get("brand"),
        category=best_row.get("category"),
        quantity=best_row.get("quantity"),
        unit=best_row.get("unit"),
        storage_location=best_row.get("storage_location"),
        estimated_expiry_days=best_row.get("estimated_expiry_days"),
        expiry_confidence=best_row.get("expiry_confidence") or "medium",
        image_url=image_url,
        source=source,
    )


def enrich_detected_products_from_cache(analysis: dict[str, Any]) -> dict[str, Any]:
    products = analysis.get("products")
    if not isinstance(products, list):
        return analysis

    enriched_products = []
    for product in products:
        if not isinstance(product, dict):
            enriched_products.append(product)
            continue

        cached = find_cached_product_for_name(
            product.get("normalized_name") or product.get("name")
        )
        if cached is None:
            enriched_products.append(product)
            continue

        merged = dict(product)
        if not merged.get("barcode") and cached.barcode:
            merged["barcode"] = cached.barcode
        if _is_generic_category(merged.get("category")) and cached.category:
            merged["category"] = cached.category
        if not merged.get("storage_location") and cached.storage_location:
            merged["storage_location"] = cached.storage_location
        if not merged.get("estimated_expiry_days") and cached.estimated_expiry_days:
            merged["estimated_expiry_days"] = cached.estimated_expiry_days
            merged["expiry_confidence"] = cached.expiry_confidence
        if not merged.get("image_url") and cached.image_url:
            merged["image_url"] = cached.image_url
        if not merged.get("normalized_name"):
            merged["normalized_name"] = _clean_product_name(
                merged.get("name")
            ).lower()
        enriched_products.append(merged)

    enriched = dict(analysis)
    enriched["products"] = enriched_products
    return enriched


def _meaningful_name_tokens(value: str | None) -> set[str]:
    cleaned = _clean_product_name(value).lower()
    cleaned = re.sub(r"\bqued[oó]\b", "queso", cleaned)
    words = re.findall(r"[a-záéíóúüñ]{3,}", cleaned)
    stopwords = {
        "con",
        "del",
        "los",
        "las",
        "una",
        "uno",
        "natural",
        "pack",
        "producto",
        "mercadona",
        "hacendado",
    }
    return {word for word in words if word not in stopwords}


def _is_generic_category(value: Any) -> bool:
    return value in {None, "", "other", "other_refrigerated"}


def upsert_cached_barcode_product(product) -> None:
    barcode = (product.barcode or "").strip()
    if not barcode:
        return

    clean_name = _clean_product_name(product.normalized_name or product.name)
    row = {
        "barcode": barcode,
        "name": clean_name,
        "normalized_name": clean_name.lower(),
        "brand": None,
        "category": product.category,
        "quantity": product.quantity,
        "unit": product.unit,
        "storage_location": product.storage_location,
        "estimated_expiry_days": product.estimated_expiry_days,
        "expiry_confidence": product.expiry_confidence,
        "image_url": product.image_url,
        "source": "frigocheck_cache",
    }

    supabase = get_supabase_client()
    try:
        supabase.table(BARCODE_CACHE_TABLE).upsert(row, on_conflict="barcode").execute()
    except Exception:
        return


def upload_processed_product_image(
    *,
    barcode: str,
    image_bytes: bytes | None,
) -> tuple[str | None, str | None]:
    if not barcode or not image_bytes:
        return None, None

    bucket = settings.PRODUCT_IMAGE_BUCKET.strip() or "product-images"
    _ensure_product_image_bucket(bucket)
    storage_path = f"barcodes/{barcode}.png"
    supabase_url = _normalize_supabase_url(settings.SUPABASE_URL)
    object_url = (
        f"{supabase_url}/storage/v1/object/{quote(bucket)}/"
        f"{quote(storage_path, safe='/')}"
    )
    request = Request(
        object_url,
        data=image_bytes,
        method="POST",
        headers={
            "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
            "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
            "Content-Type": "image/png",
            "x-upsert": "true",
        },
    )
    try:
        with urlopen(request, timeout=8):
            public_url = (
                f"{supabase_url}/storage/v1/object/public/{quote(bucket)}/"
                f"{quote(storage_path, safe='/')}"
            )
            return public_url, storage_path
    except (HTTPError, URLError, TimeoutError):
        return None, None


def _ensure_product_image_bucket(bucket: str) -> None:
    supabase_url = _normalize_supabase_url(settings.SUPABASE_URL)
    bucket_url = f"{supabase_url}/storage/v1/bucket"
    payload = json.dumps(
        {
            "id": bucket,
            "name": bucket,
            "public": True,
            "file_size_limit": 5_242_880,
            "allowed_mime_types": ["image/png", "image/jpeg", "image/webp"],
        }
    ).encode("utf-8")
    request = Request(
        bucket_url,
        data=payload,
        method="POST",
        headers={
            "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
            "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
            "Content-Type": "application/json",
        },
    )
    try:
        with urlopen(request, timeout=5):
            return
    except HTTPError as exc:
        if exc.code in {400, 409}:
            return
    except (URLError, TimeoutError):
        return


def upsert_enriched_barcode_product(
    product: BarcodeProductLookup,
    *,
    original_image_url: str | None = None,
    processed_image_url: str | None = None,
    image_storage_path: str | None = None,
    image_processing_status: str | None = None,
    provider_source: str | None = None,
    is_verified: bool = False,
) -> None:
    barcode = (product.barcode or "").strip()
    if not barcode or not product.found:
        return

    clean_name = _clean_product_name(product.normalized_name or product.name)
    source = "frigocheck_verified" if is_verified else "external_cache"
    row = {
        "barcode": barcode,
        "name": clean_name,
        "normalized_name": clean_name.lower(),
        "brand": product.brand,
        "category": product.category,
        "quantity": product.quantity,
        "unit": product.unit,
        "storage_location": product.storage_location,
        "estimated_expiry_days": product.estimated_expiry_days,
        "expiry_confidence": product.expiry_confidence,
        "image_url": processed_image_url or product.image_url,
        "original_image_url": original_image_url,
        "processed_image_url": processed_image_url or product.image_url,
        "image_storage_path": image_storage_path,
        "image_processing_status": image_processing_status
        or ("processed_v2" if processed_image_url else "fallback"),
        "provider_source": provider_source or product.source,
        "source": source,
        "is_verified": is_verified,
        "confidence_score": 0.95 if is_verified else 0.70,
        "last_lookup_at": datetime.utcnow().isoformat(),
    }

    _upsert_barcode_cache_row(row)


def _upsert_barcode_cache_row(row: dict[str, Any]) -> None:
    supabase = get_supabase_client()
    try:
        supabase.table(BARCODE_CACHE_TABLE).upsert(row, on_conflict="barcode").execute()
    except Exception as exc:
        missing_field = _optional_barcode_cache_field_from_error(str(exc))
        if not missing_field:
            return
        fallback = dict(row)
        fallback.pop(missing_field, None)
        _upsert_barcode_cache_row(fallback)


def _optional_barcode_cache_field_from_error(message: str) -> str | None:
    if "schema cache" not in message and "column" not in message:
        return None
    for field in BARCODE_CACHE_OPTIONAL_FIELDS:
        if field in message:
            return field
    return None


def _refresh_cached_image_if_needed(row: dict[str, Any]) -> dict[str, Any]:
    if row.get("image_processing_status") in {"processed_v2", "ai_cleaned"}:
        return row

    barcode = row.get("barcode")
    original_image_url = row.get("original_image_url")
    if not barcode or not original_image_url:
        return row

    try:
        from app.services.product_image_service import standardize_product_image_bytes

        image_bytes = standardize_product_image_bytes(original_image_url)
        processed_image_url, image_storage_path = upload_processed_product_image(
            barcode=barcode,
            image_bytes=image_bytes,
        )
        if not processed_image_url:
            return row

        update = {
            "image_url": processed_image_url,
            "processed_image_url": processed_image_url,
            "image_storage_path": image_storage_path,
            "image_processing_status": "processed_v2",
            "last_lookup_at": datetime.utcnow().isoformat(),
        }
        get_supabase_client().table(BARCODE_CACHE_TABLE).update(update).eq(
            "barcode", barcode
        ).execute()
        return {**row, **update}
    except Exception:
        return row


def save_receipt_with_products(payload: SaveReceiptRequest, user_id: str) -> dict[str, Any]:
    supabase = get_supabase_client()

    saved_products_total = sum((product.price or 0) for product in payload.products)
    receipt_insert = {
        "user_id": user_id,
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
        clean_name = _clean_product_name(product.normalized_name or product.name)
        product_rows.append(
            {
                "user_id": user_id,
                "receipt_id": receipt_id,
                "name": clean_name,
                "normalized_name": clean_name.lower(),
                "barcode": product.barcode,
                "category": product.category,
                "quantity": product.quantity,
                "unit": product.unit,
                "storage_location": product.storage_location,
                "purchase_date": added_date,
                "estimated_expiry_date": estimated_expiry_date,
                "expiry_confidence": product.expiry_confidence,
                "price": product.price,
                "image_url": product.image_url,
                "status": "active",
                "notes": _product_notes_payload(product),
            }
        )

    products_saved = 0
    if product_rows:
        products_result = _insert_products_with_price_fallback(supabase, product_rows)
        products_saved = len(products_result.data or [])
        for saved_product in products_result.data or []:
            event_rows.append(
                {
                    "user_id": user_id,
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
    if "name" in update_data:
        update_data["name"] = _clean_product_name(update_data["name"])
    if "normalized_name" in update_data:
        update_data["normalized_name"] = _clean_product_name(update_data["normalized_name"]).lower()

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
        elif days_left <= 4:
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
        "current_streak": _calculate_current_streak(user_id=user_id),
        "score": score,
        "level": _level_for_score(score, usage_percentage),
    }


def _parse_event_date(value: str | None) -> date | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).date()
    except ValueError:
        return None


def _events_for_user(user_id: str) -> list[dict[str, Any]]:
    supabase = get_supabase_client()
    result = (
        supabase.table("product_events")
        .select("event_type,event_date,product_id")
        .eq("user_id", user_id)
        .in_("event_type", ["consumed", "expired", "wasted"])
        .execute()
    )
    return result.data or []


def _calculate_current_streak(user_id: str) -> int:
    events = _events_for_user(user_id)
    consumed_dates = {
        parsed
        for event in events
        if event.get("event_type") == "consumed"
        for parsed in [_parse_event_date(event.get("event_date"))]
        if parsed is not None
    }
    if not consumed_dates:
        return 0

    streak = 0
    cursor = date.today()
    while cursor in consumed_dates:
        streak += 1
        cursor -= timedelta(days=1)
    return streak


def _level_for_score(score: int, usage_percentage: int) -> str:
    if score >= 500 and usage_percentage >= 85:
        return "Maestro FrigoCheck"
    if score >= 250 and usage_percentage >= 70:
        return "Nevera en control"
    if score >= 100:
        return "Ahorrador constante"
    return "Aprendiz anti-desperdicio"


def get_daily_stats_for_user(user_id: str, year: int, month: int) -> dict[str, Any]:
    products = {product.get("id"): product for product in list_products_for_user(user_id=user_id)}
    days_in_month = calendar.monthrange(year, month)[1]
    daily = {
        day: {"date": date(year, month, day).isoformat(), "savings": 0.0, "waste": 0.0, "consumed_count": 0, "expired_count": 0}
        for day in range(1, days_in_month + 1)
    }

    for event in _events_for_user(user_id):
        event_date = _parse_event_date(event.get("event_date"))
        if event_date is None or event_date.year != year or event_date.month != month:
            continue
        product = products.get(event.get("product_id"), {})
        price = float(product.get("price") or 0)
        bucket = daily[event_date.day]
        if event.get("event_type") == "consumed":
            bucket["savings"] += price
            bucket["consumed_count"] += 1
        elif event.get("event_type") in {"expired", "wasted"}:
            bucket["waste"] += price
            bucket["expired_count"] += 1

    return {
        "year": year,
        "month": month,
        "days": [
            {
                **value,
                "savings": round(float(value["savings"]), 2),
                "waste": round(float(value["waste"]), 2),
            }
            for value in daily.values()
        ],
    }
