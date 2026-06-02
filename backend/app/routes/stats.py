from fastapi import APIRouter

router = APIRouter()


@router.get("/summary")
def get_stats_summary():
    """Temporary mock stats until Supabase is connected."""
    return {
        "consumed_count": 28,
        "wasted_count": 3,
        "current_streak": 6,
        "estimated_savings": 18.40,
        "usage_percentage": 90,
        "level": "Nevera en control",
    }
