from fastapi import APIRouter, HTTPException, Query

from app.schemas.receipt import UpdateProductRequest
from app.services.supabase_service import (
    delete_product_for_user,
    get_product_for_user,
    list_products_for_user,
    mark_product_status,
    update_product_for_user,
)

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


@router.get("/{product_id}")
def get_product(product_id: str, user_id: str = Query(...)):
    """Get one product by ID."""
    try:
        return {"product": get_product_for_user(product_id=product_id, user_id=user_id)}
    except Exception as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.patch("/{product_id}")
def update_product(product_id: str, payload: UpdateProductRequest, user_id: str = Query(...)):
    """Edit an active product before it reaches a final state."""
    try:
        product = update_product_for_user(product_id=product_id, user_id=user_id, payload=payload)
        return {"status": "ok", "product": product}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.delete("/{product_id}")
def delete_product(product_id: str, user_id: str = Query(...)):
    """Soft-delete a product."""
    try:
        product = delete_product_for_user(product_id=product_id, user_id=user_id)
        return {"status": "ok", "product": product}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


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
        raise HTTPException(status_code=400, detail=str(exc))


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
        raise HTTPException(status_code=400, detail=str(exc))
