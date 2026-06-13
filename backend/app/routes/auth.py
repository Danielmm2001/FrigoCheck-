import re
import time
from collections import defaultdict, deque

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from app.services.supabase_service import get_auth_email_status

router = APIRouter()

EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
WINDOW_SECONDS = 60
MAX_REQUESTS_PER_WINDOW = 20
_requests_by_ip: dict[str, deque[float]] = defaultdict(deque)


class EmailStatusRequest(BaseModel):
    email: str


@router.post("/email-status")
def email_status(payload: EmailStatusRequest, request: Request):
    _check_rate_limit(request)

    email = payload.email.strip().lower()
    if not EMAIL_PATTERN.match(email):
        raise HTTPException(status_code=400, detail="Invalid email")

    return get_auth_email_status(email)


def _check_rate_limit(request: Request) -> None:
    client_ip = request.client.host if request.client else "unknown"
    now = time.monotonic()
    timestamps = _requests_by_ip[client_ip]

    while timestamps and now - timestamps[0] > WINDOW_SECONDS:
        timestamps.popleft()

    if len(timestamps) >= MAX_REQUESTS_PER_WINDOW:
        raise HTTPException(status_code=429, detail="Too many requests")

    timestamps.append(now)
