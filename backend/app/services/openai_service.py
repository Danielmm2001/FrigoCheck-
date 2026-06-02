import base64
import json
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
