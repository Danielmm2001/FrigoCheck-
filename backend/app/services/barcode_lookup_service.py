import json
import re
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from app.config import settings
from app.schemas.receipt import BarcodeProductLookup
from app.services.product_image_service import standardize_product_image_bytes, standardize_product_image_url
from app.services.supabase_service import (
    _clean_product_name,
    get_cached_barcode_product,
    upload_processed_product_image,
    upsert_enriched_barcode_product,
)


OPEN_FOOD_FACTS_FIELDS = ",".join(
    [
        "product_name",
        "product_name_es",
        "generic_name",
        "brands",
        "categories",
        "categories_tags",
        "quantity",
        "image_front_url",
        "image_url",
    ]
)


OPEN_FACTS_PROVIDERS = [
    ("open_food_facts", "https://world.openfoodfacts.org"),
    ("open_products_facts", "https://world.openproductsfacts.org"),
]


def lookup_barcode_product(barcode: str) -> BarcodeProductLookup:
    clean_barcode = re.sub(r"\D+", "", barcode or "")
    if len(clean_barcode) < 8:
        return BarcodeProductLookup(
            barcode=clean_barcode,
            found=False,
            message="Codigo de barras no valido",
        )

    cached_product = get_cached_barcode_product(clean_barcode)
    if cached_product:
        return cached_product

    for source, base_url in OPEN_FACTS_PROVIDERS:
        product = _fetch_open_facts_product(clean_barcode, base_url=base_url)
        if product:
            lookup = _lookup_from_open_facts_product(
                barcode=clean_barcode,
                product=product,
                source=source,
            )
            return _cache_and_return_lookup(
                lookup,
                original_image_url=_product_image_url(product),
            )

    commercial_lookup = _fetch_barcode_lookup_product(clean_barcode)
    if commercial_lookup:
        return _cache_and_return_lookup(
            commercial_lookup,
            original_image_url=commercial_lookup.image_url,
        )

    return BarcodeProductLookup(
        barcode=clean_barcode,
        found=False,
        source="open_food_facts,open_products_facts,barcode_lookup",
        message="Producto no encontrado",
    )


def _lookup_from_open_facts_product(
    barcode: str,
    product: dict[str, Any],
    source: str,
) -> BarcodeProductLookup:
    category = _map_category(product)
    quantity, unit = _parse_quantity(product.get("quantity"))
    expiry_days = _estimated_expiry_days(category)
    name = _product_name(product) or "Producto"
    normalized_name = _clean_product_name(name)

    return BarcodeProductLookup(
        barcode=barcode,
        found=True,
        name=normalized_name,
        normalized_name=normalized_name.lower(),
        brand=_first_brand(product.get("brands")),
        category=category,
        quantity=quantity,
        unit=unit,
        storage_location="freezer" if category == "frozen" else "fridge",
        estimated_expiry_days=expiry_days,
        expiry_confidence="medium",
        image_url=_product_image_url(product),
        source=source,
    )


def _fetch_open_facts_product(barcode: str, base_url: str) -> dict[str, Any] | None:
    url = (
        f"{base_url}/api/v2/product/"
        f"{quote(barcode)}.json?fields={quote(OPEN_FOOD_FACTS_FIELDS)}"
    )
    request = Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "FrigoCheck/0.1 barcode-lookup",
        },
    )
    try:
        with urlopen(request, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError):
        return None

    if payload.get("status") != 1:
        return None
    product = payload.get("product")
    return product if isinstance(product, dict) else None


def _fetch_barcode_lookup_product(barcode: str) -> BarcodeProductLookup | None:
    api_key = settings.BARCODE_LOOKUP_API_KEY.strip()
    if not api_key:
        return None

    url = (
        "https://api.barcodelookup.com/v3/products"
        f"?barcode={quote(barcode)}&formatted=y&key={quote(api_key)}"
    )
    request = Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "FrigoCheck/0.1 barcode-lookup",
        },
    )
    try:
        with urlopen(request, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError):
        return None

    products = payload.get("products")
    if not isinstance(products, list) or not products:
        return None
    product = products[0]
    if not isinstance(product, dict):
        return None

    name = _string_value(product.get("title")) or _string_value(product.get("product_name"))
    if not name:
        return None

    category = _map_category(
        {
            "categories": _string_value(product.get("category")),
            "product_name": name,
        }
    )
    quantity, unit = _parse_quantity(product.get("size"))
    image_url = _first_image(product.get("images"))
    normalized_name = _clean_product_name(name)

    return BarcodeProductLookup(
        barcode=barcode,
        found=True,
        name=normalized_name,
        normalized_name=normalized_name.lower(),
        brand=_string_value(product.get("brand")),
        category=category,
        quantity=quantity,
        unit=unit,
        storage_location="freezer" if category == "frozen" else "fridge",
        estimated_expiry_days=_estimated_expiry_days(category),
        expiry_confidence="medium",
        image_url=image_url,
        source="barcode_lookup",
    )


def _cache_and_return_lookup(
    product: BarcodeProductLookup,
    *,
    original_image_url: str | None,
) -> BarcodeProductLookup:
    if not product.found:
        return product

    processed_image_url = None
    image_storage_path = None
    if original_image_url:
        image_bytes = standardize_product_image_bytes(original_image_url)
        processed_image_url, image_storage_path = upload_processed_product_image(
            barcode=product.barcode,
            image_bytes=image_bytes,
        )
        product.image_url = processed_image_url or standardize_product_image_url(original_image_url)

    upsert_enriched_barcode_product(
        product,
        original_image_url=original_image_url,
        processed_image_url=processed_image_url,
        image_storage_path=image_storage_path,
        provider_source=product.source,
        is_verified=False,
    )
    return product


def _product_name(product: dict[str, Any]) -> str | None:
    for key in ("product_name_es", "product_name", "generic_name"):
        value = product.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _product_image_url(product: dict[str, Any]) -> str | None:
    return _string_value(product.get("image_front_url")) or _string_value(product.get("image_url"))


def _first_brand(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    return value.split(",")[0].strip() or None


def _string_value(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    cleaned = value.strip()
    return cleaned or None


def _first_image(value: Any) -> str | None:
    if isinstance(value, list):
        for item in value:
            if isinstance(item, str) and item.strip():
                return item.strip()
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _map_category(product: dict[str, Any]) -> str:
    raw_values = []
    tags = product.get("categories_tags")
    if isinstance(tags, list):
        raw_values.extend(str(tag) for tag in tags)
    for key in ("categories", "product_name", "product_name_es", "generic_name"):
        value = product.get(key)
        if isinstance(value, str):
            raw_values.append(value)

    text = " ".join(raw_values).lower()
    rules = [
        (("yogurt", "yoghurt", "yogur"), "yogurt"),
        (("cheese", "queso"), "cheese"),
        (("milk", "leche", "dairy", "lacteo", "lacteos"), "dairy"),
        (("chicken", "pollo", "pavo", "turkey"), "poultry"),
        (("meat", "carne", "beef", "cerdo", "pork"), "meat"),
        (("fish", "pescado", "salmon", "atun", "tuna"), "fish"),
        (("seafood", "marisco", "gamba", "shrimp"), "seafood"),
        (("egg", "huevo"), "eggs"),
        (("frozen", "congelado", "congelados"), "frozen"),
        (("fruit", "fruta"), "fruit"),
        (("vegetable", "verdura", "hortaliza", "ensalada"), "vegetables"),
        (("ready-meal", "prepared", "plato preparado"), "refrigerated_ready_meal"),
    ]
    for needles, category in rules:
        if any(needle in text for needle in needles):
            return category
    return "other_refrigerated"


def _parse_quantity(value: Any) -> tuple[float | None, str | None]:
    if not isinstance(value, str):
        return None, None
    match = re.search(r"(\d+(?:[,.]\d+)?)\s*(kg|g|l|ml|cl|ud|u)\b", value, re.IGNORECASE)
    if not match:
        return None, None
    number = float(match.group(1).replace(",", "."))
    unit = match.group(2).lower()
    if unit == "kg":
        return number * 1000, "g"
    if unit == "l":
        return number * 1000, "ml"
    if unit == "cl":
        return number * 10, "ml"
    if unit == "u":
        return number, "ud"
    return number, unit


def _estimated_expiry_days(category: str) -> int | None:
    return {
        "fish": 2,
        "seafood": 2,
        "meat": 3,
        "poultry": 3,
        "refrigerated_ready_meal": 4,
        "eggs": 21,
        "yogurt": 14,
        "dairy": 7,
        "cheese": 14,
        "fruit": 5,
        "vegetables": 5,
        "frozen": 90,
        "other_refrigerated": 7,
    }.get(category)
