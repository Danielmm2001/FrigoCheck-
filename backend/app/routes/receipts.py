from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.schemas.receipt import SaveReceiptRequest, SaveReceiptResponse
from app.services.openai_service import analyze_expiry_date_image, analyze_receipt_image
from app.services.supabase_service import save_receipt_with_products

router = APIRouter()


@router.post("/analyze")
async def analyze_receipt(user_id: str = Form(...), image: UploadFile = File(...)):
    """Analyze a receipt image and return detected products."""
    try:
        image_bytes = await image.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Image file is empty")

        result = await analyze_receipt_image(
            image_bytes=image_bytes,
            filename=image.filename,
        )
        return result
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/save", response_model=SaveReceiptResponse)
def save_receipt(payload: SaveReceiptRequest):
    """Save a confirmed receipt and its detected products into Supabase."""
    try:
        return save_receipt_with_products(payload)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/expiry-date/analyze")
async def analyze_expiry_date(
    image: UploadFile = File(...),
    product_name: str | None = Form(default=None),
):
    """Analyze a package expiry date image and return the exact days left when readable."""
    try:
        image_bytes = await image.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Image file is empty")

        return await analyze_expiry_date_image(
            image_bytes=image_bytes,
            filename=image.filename,
            product_name=product_name,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
