from fastapi import APIRouter, HTTPException, Query

from app.services.supabase_service import get_daily_stats_for_user, get_stats_summary_for_user

router = APIRouter()


@router.get("/summary")
def get_stats_summary(user_id: str = Query(...)):
    """Return real summary stats for one user."""
    try:
        return get_stats_summary_for_user(user_id=user_id)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/daily")
def get_daily_stats(
    user_id: str = Query(...),
    year: int = Query(..., ge=2000, le=2100),
    month: int = Query(..., ge=1, le=12),
):
    """Return day-by-day savings and waste for a calendar month."""
    try:
        return get_daily_stats_for_user(user_id=user_id, year=year, month=month)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
