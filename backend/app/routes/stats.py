from fastapi import APIRouter, HTTPException, Query

from app.services.supabase_service import get_stats_summary_for_user

router = APIRouter()


@router.get("/summary")
def get_stats_summary(user_id: str = Query(...)):
    """Return real summary stats for one user."""
    try:
        return get_stats_summary_for_user(user_id=user_id)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
