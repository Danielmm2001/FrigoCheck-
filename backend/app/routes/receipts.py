from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.services.openai_service import analyze_receipt_image

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
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/save")
def save_receipt():
    """Placeholder for saving confirmed receipt/products into Supabase."""
    return {"status": "pending", "message": "Save receipt endpoint not implemented yet"}
