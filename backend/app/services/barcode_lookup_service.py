import json
import re
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from app.schemas.receipt import BarcodeProductLookup
from app.services.supabase_service import _clean_product_name


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


def lookup_barcode_product(barcode: str) -> BarcodeProductLookup:
    clean_barcode = re.sub(r"\D+", "", barcode or "")
    if len(clean_barcode) < 8:
        return BarcodeProductLookup(
            barcode=clean_barcode,
            found=False,
            message="Codigo de barras no valido",
        )

    product = _fetch_open_food_facts_product(clean_barcode)
    if not product:
        return BarcodeProductLookup(
            barcode=clean_barcode,
            found=False,
            source="open_food_facts",
            message="Producto no encontrado",
        )

    category = _map_category(product)
    quantity, unit = _parse_quantity(product.get("quantity"))
    expiry_days = _estimated_expiry_days(category)
    name = _product_name(product) or "Producto"
    normalized_name = _clean_product_name(name)

    return BarcodeProductLookup(
        barcode=clean_barcode,
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
        image_url=product.get("image_front_url") or product.get("image_url"),
        source="open_food_facts",
    )


def _fetch_open_food_facts_product(barcode: str) -> dict[str, Any] | None:
    url = (
        "https://world.openfoodfacts.org/api/v2/product/"
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


def _product_name(product: dict[str, Any]) -> str | None:
    for key in ("product_name_es", "product_name", "generic_name"):
        value = product.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _first_brand(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    return value.split(",")[0].strip() or None


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
