import base64
import json
import re
from datetime import date, datetime
from typing import Any

from openai import OpenAI

from app.config import settings
from app.prompts.receipt_extractor import SYSTEM_PROMPT, USER_PROMPT


def _get_client() -> OpenAI:
    if not settings.OPENAI_API_KEY:
        raise RuntimeError("OPENAI_API_KEY is not configured")
    return OpenAI(api_key=settings.OPENAI_API_KEY)


async def analyze_receipt_image(image_bytes: bytes, filename: str | None = None) -> dict[str, Any]:
    """Analyze a receipt image with OpenAI vision and return structured JSON."""
    encoded = base64.b64encode(image_bytes).decode("utf-8")
    mime_type = "image/jpeg"
    if filename and filename.lower().endswith(".png"):
        mime_type = "image/png"

    client = _get_client()
    response = client.responses.create(
        model="gpt-4.1-mini",
        input=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": USER_PROMPT},
                    {
                        "type": "input_image",
                        "image_url": f"data:{mime_type};base64,{encoded}",
                    },
                ],
            },
        ],
    )

    text = response.output_text.strip()
    return json.loads(text)


async def analyze_expiry_date_image(
    image_bytes: bytes,
    filename: str | None = None,
    product_name: str | None = None,
) -> dict[str, Any]:
    """Read an expiry date printed on a package and return a conservative result."""
    encoded = base64.b64encode(image_bytes).decode("utf-8")
    mime_type = "image/jpeg"
    if filename and filename.lower().endswith(".png"):
        mime_type = "image/png"

    today = date.today()
    product_hint = product_name or "producto"
    client = _get_client()
    response = client.responses.create(
        model="gpt-4.1-mini",
        input=[
            {
                "role": "system",
                "content": (
                    "Eres un lector de fechas de caducidad en envases de comida. "
                    "Devuelve solo JSON valido, sin markdown. Si no hay una fecha clara, "
                    "usa null. No inventes fechas."
                ),
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_text",
                        "text": (
                            f"Hoy es {today.isoformat()}. Producto: {product_hint}. "
                            "Lee la fecha impresa de caducidad o consumo preferente. "
                            "Acepta formatos como 18/06/26, 18 JUN 2026, CAD 18-06, "
                            "VTO 18.06.2026. Si falta el año, asume el año futuro mas cercano "
                            "respecto a hoy. Responde exactamente con este JSON: "
                            '{"expiry_date":"YYYY-MM-DD|null","raw_text":"texto visto",'
                            '"confidence":"high|medium|low","reason":"breve"}'
                        ),
                    },
                    {
                        "type": "input_image",
                        "image_url": f"data:{mime_type};base64,{encoded}",
                    },
                ],
            },
        ],
    )

    payload = _loads_json_object(response.output_text)
    expiry_date = payload.get("expiry_date")
    days_left = None
    if isinstance(expiry_date, str):
        expiry_date = expiry_date.strip()
        if expiry_date.lower() == "null":
            expiry_date = None
        else:
            parsed = datetime.strptime(expiry_date, "%Y-%m-%d").date()
            days_left = (parsed - today).days

    return {
        "expiry_date": expiry_date,
        "days_left": days_left,
        "raw_text": payload.get("raw_text"),
        "confidence": payload.get("confidence") or "low",
        "reason": payload.get("reason"),
    }


def _loads_json_object(text: str) -> dict[str, Any]:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?", "", cleaned, flags=re.IGNORECASE).strip()
        cleaned = re.sub(r"```$", "", cleaned).strip()
    return json.loads(cleaned)
