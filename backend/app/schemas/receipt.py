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


class UpdateProductRequest(BaseModel):
    name: str | None = None
    normalized_name: str | None = None
    category: str | None = None
    quantity: float | None = None
    unit: str | None = None
    storage_location: str | None = None
    purchase_date: str | None = None
    estimated_expiry_date: str | None = None
    expiry_confidence: str | None = None
    notes: str | None = None
