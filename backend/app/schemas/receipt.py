from pydantic import BaseModel, Field


class StoreData(BaseModel):
    name: str | None = None
    purchase_date: str | None = None
    total_amount: float | None = None


class DetectedProduct(BaseModel):
    name: str
    normalized_name: str | None = None
    category: str = "other"
    quantity: float = 1
    unit: str = "ud"
    storage_location: str = "fridge"
    estimated_expiry_days: int | None = None
    expiry_confidence: str = "medium"
    confidence: str = "medium"
    notes: str | None = None


class SaveReceiptRequest(BaseModel):
    user_id: str = Field(..., description="Temporary user id until auth is connected")
    store: StoreData
    products: list[DetectedProduct]
    warnings: list[str] = []
    raw_ai_response: dict | None = None


class SaveReceiptResponse(BaseModel):
    receipt_id: str
    products_saved: int
