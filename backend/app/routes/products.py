from fastapi import APIRouter

router = APIRouter()


@router.get("")
def list_products():
    """Temporary mock list until Supabase is connected."""
    return {
        "products": [
            {
                "id": "mock-1",
                "name": "Arándanos",
                "quantity": 1,
                "unit": "pack",
                "status": "active",
                "estimated_expiry_days": 3,
            },
            {
                "id": "mock-2",
                "name": "Pechuga de pollo",
                "quantity": 1,
                "unit": "pack",
                "status": "active",
                "estimated_expiry_days": 1,
            },
        ]
    }


@router.post("/{product_id}/consume")
def consume_product(product_id: str):
    return {"status": "ok", "product_id": product_id, "action": "consumed"}


@router.post("/{product_id}/waste")
def waste_product(product_id: str):
    return {"status": "ok", "product_id": product_id, "action": "wasted"}
