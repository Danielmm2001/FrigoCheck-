from fastapi import APIRouter, HTTPException, Query

from app.services.supabase_service import list_products_for_user, mark_product_status

router = APIRouter()


@router.get("")
def list_products(
    user_id: str = Query(...),
    status: str | None = Query(default=None),
):
    """List products saved in Supabase for one user."""
    try:
        return {"products": list_products_for_user(user_id=user_id, status=status)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/{product_id}/consume")
def consume_product(product_id: str, user_id: str = Query(...)):
    """Mark a product as consumed."""
    try:
        product = mark_product_status(
            product_id=product_id,
            user_id=user_id,
            status="consumed",
            event_type="consumed",
        )
        return {"status": "ok", "product": product}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/{product_id}/waste")
def waste_product(product_id: str, user_id: str = Query(...)):
    """Mark a product as wasted."""
    try:
        product = mark_product_status(
            product_id=product_id,
            user_id=user_id,
            status="wasted",
            event_type="wasted",
        )
        return {"status": "ok", "product": product}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
