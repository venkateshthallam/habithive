from fastapi import APIRouter, HTTPException, status, Depends, Query
from app.models.schemas import ActivityEvent, YearOverviewResponse, HabitHeatmapSeries
from app.core.auth import get_current_user
from app.core.supabase import get_user_supabase_client
from app.core.config import settings
from typing import Dict, Any, List, Optional
from datetime import datetime, date, timedelta
import uuid

router = APIRouter()

# In-memory storage for test mode
test_activity = []

# Import shared test data (if needed)
def get_test_profiles():
    from app.routers.profiles import test_profiles
    return test_profiles

def get_test_habits():
    from app.routers.habits import test_habits
    return test_habits

def get_test_logs():
    from app.routers.habits import test_logs
    return test_logs

def get_test_hive_members():
    from app.routers.hives import test_hive_members
    return test_hive_members

def get_test_hives():
    from app.routers.hives import test_hives
    return test_hives

@router.get("/feed", response_model=List[ActivityEvent])
async def get_activity_feed(
    current_user: Dict[str, Any] = Depends(get_current_user),
    hive_id: Optional[str] = Query(None, description="Filter by hive"),
    limit: int = Query(50, le=100, description="Number of events to return")
):
    """Get activity feed for user's hives"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        # Get user's hive IDs
        test_hive_members = get_test_hive_members()
        user_hive_ids = [m["hive_id"] for m in test_hive_members.values() 
                        if m["user_id"] == user_id]
        
        # Filter activity
        filtered_activity = []
        for event in test_activity:
            if hive_id:
                # Filter by specific hive
                if event["hive_id"] == hive_id:
                    filtered_activity.append(event)
            else:
                # Show activity from all user's hives
                if event["hive_id"] in user_hive_ids:
                    filtered_activity.append(event)
        
        # Sort by created_at descending
        filtered_activity.sort(key=lambda x: x["created_at"], reverse=True)
        
        # Limit results
        filtered_activity = filtered_activity[:limit]
        
        # Add actor info if available
        result = []
        test_profiles = get_test_profiles()
        for event in filtered_activity:
            event_with_actor = event.copy()
            if event["actor_id"] in test_profiles:
                profile = test_profiles[event["actor_id"]]
                event_with_actor["actor_name"] = profile["display_name"]
                event_with_actor["actor_avatar"] = profile["avatar_url"]
            result.append(ActivityEvent(**event_with_actor))
        
        return result
    
    try:
        supabase = get_user_supabase_client(current_user)
        
        # Get user's hive IDs
        member_response = supabase.table("hive_members").select("hive_id").eq("user_id", user_id).execute()
        user_hive_ids = [m["hive_id"] for m in member_response.data]
        
        if not user_hive_ids:
            return []
        
        # Build query
        query = supabase.table("activity_events").select("*, profiles!actor_id(display_name, avatar_url)")
        
        if hive_id:
            query = query.eq("hive_id", hive_id)
        else:
            query = query.in_("hive_id", user_hive_ids)
        
        query = query.order("created_at", desc=True).limit(limit)
        
        response = query.execute()
        
        # Format response
        result = []
        for event in response.data:
            event_data = {
                **event,
                "actor_name": event.get("profiles", {}).get("display_name"),
                "actor_avatar": event.get("profiles", {}).get("avatar_url")
            }
            result.append(ActivityEvent(**event_data))
        
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch activity feed: {str(e)}"
        )


@router.get("/year-overview", response_model=YearOverviewResponse)
async def get_year_overview(
    current_user: Dict[str, Any] = Depends(get_current_user),
    year: Optional[int] = Query(None, ge=2000, le=3000, description="Calendar year to summarise")
):
    """Return per-day completion counts for the selected year."""
    user_id = current_user["id"]

    today = date.today()
    target_year = year or today.year
    start_date = date(target_year, 1, 1)
    end_date = date(target_year, 12, 31)

    def build_response(habits: List[Dict[str, Any]], logs: List[Dict[str, Any]]) -> YearOverviewResponse:
        active_habits = [h for h in habits if h.get("is_active", True)]
        habit_map: Dict[str, Dict[str, Any]] = {}
        for habit in active_habits:
            hid = str(habit["id"])
            habit_map[hid] = habit

        totals: Dict[str, int] = {}
        per_habit: Dict[str, Dict[str, int]] = {}

        for entry in logs:
            hid = str(entry.get("habit_id"))
            habit = habit_map.get(hid)
            if habit is None:
                continue

            raw_date = entry.get("log_date")
            if isinstance(raw_date, str):
                log_date = date.fromisoformat(raw_date)
            elif isinstance(raw_date, datetime):
                log_date = raw_date.date()
            else:
                log_date = raw_date

            if log_date is None or log_date < start_date or log_date > end_date:
                continue

            target = int(habit.get("target_per_day") or 1)
            value = int(entry.get("value", 0) or 0)
            normalized = max(0, min(value, target if target > 0 else value))
            if normalized == 0:
                continue

            key = log_date.isoformat()
            totals[key] = totals.get(key, 0) + normalized
            habit_bucket = per_habit.setdefault(hid, {})
            habit_bucket[key] = habit_bucket.get(key, 0) + normalized

        series: List[HabitHeatmapSeries] = []
        for hid, habit in habit_map.items():
            counts = per_habit.get(hid, {})
            series.append(
                HabitHeatmapSeries(
                    habit_id=uuid.UUID(str(hid)),
                    name=habit.get("name", ""),
                    emoji=habit.get("emoji"),
                    color_hex=habit.get("color_hex", "#FF9F1C"),
                    counts=counts,
                )
            )

        series.sort(key=lambda item: item.name.lower())

        max_total = max(totals.values(), default=0)

        return YearOverviewResponse(
            start_date=start_date,
            end_date=end_date,
            totals=totals,
            max_total=max_total,
            habits=series,
        )

    if settings.TEST_MODE:
        test_habits = list(get_test_habits().values())
        test_logs = list(get_test_logs().values())

        filtered_logs = []
        for log in test_logs:
            if log.get("user_id") != user_id:
                continue
            filtered_logs.append(log)

        return build_response(test_habits, filtered_logs)

    try:
        supabase = get_user_supabase_client(current_user)

        habits_response = (
            supabase
            .table("habits")
            .select("id, name, emoji, color_hex, target_per_day, type, is_active")
            .eq("user_id", user_id)
            .execute()
        )
        habit_rows = habits_response.data or []

        logs_response = (
            supabase
            .table("habit_logs")
            .select("habit_id, log_date, value")
            .eq("user_id", user_id)
            .gte("log_date", start_date.isoformat())
            .lte("log_date", end_date.isoformat())
            .execute()
        )
        log_rows = logs_response.data or []

        return build_response(habit_rows, log_rows)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to build year overview: {str(e)}"
        )

@router.post("/", response_model=ActivityEvent)
async def create_activity_event(
    event_type: str,
    hive_id: Optional[str] = None,
    habit_id: Optional[str] = None,
    data: dict = {},
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Create a new activity event"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        event_id = str(uuid.uuid4())
        new_event = {
            "id": event_id,
            "actor_id": user_id,
            "hive_id": hive_id,
            "habit_id": habit_id,
            "type": event_type,
            "data": data,
            "created_at": datetime.utcnow()
        }
        test_activity.append(new_event)
        
        # Add actor info
        test_profiles = get_test_profiles()
        if user_id in test_profiles:
            profile = test_profiles[user_id]
            new_event["actor_name"] = profile["display_name"]
            new_event["actor_avatar"] = profile["avatar_url"]
        
        return ActivityEvent(**new_event)
    
    try:
        supabase = get_user_supabase_client(current_user)
        
        event_data = {
            "actor_id": user_id,
            "hive_id": hive_id,
            "habit_id": habit_id,
            "type": event_type,
            "data": data
        }
        
        response = supabase.table("activity_events").insert(event_data).execute()
        
        # Get actor info
        profile_response = supabase.table("profiles").select("display_name, avatar_url").eq("id", user_id).single().execute()
        
        result = {
            **response.data[0],
            "actor_name": profile_response.data.get("display_name"),
            "actor_avatar": profile_response.data.get("avatar_url")
        }
        
        return ActivityEvent(**result)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create activity event: {str(e)}"
        )

@router.get("/milestones", response_model=List[dict])
async def get_milestones(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Get user's milestone achievements"""
    user_id = current_user["id"]
    
    milestones = []
    
    if settings.TEST_MODE:
        # Calculate milestones from test data
        test_habits = get_test_habits()
        test_logs = get_test_logs()
        user_habits = [h for h in test_habits.values() 
                      if h["user_id"] == user_id and h["is_active"]]
        
        for habit in user_habits:
            habit_logs = [l for l in test_logs.values() 
                         if l["habit_id"] == habit["id"]]
            
            if len(habit_logs) >= 7:
                milestones.append({
                    "type": "week_streak",
                    "habit_name": habit["name"],
                    "achieved_at": datetime.utcnow()
                })
            
            if len(habit_logs) >= 30:
                milestones.append({
                    "type": "month_streak",
                    "habit_name": habit["name"],
                    "achieved_at": datetime.utcnow()
                })
        
        # Check hive milestones
        test_hive_members = get_test_hive_members()
        test_hives = get_test_hives()
        user_hive_ids = [m["hive_id"] for m in test_hive_members.values() 
                        if m["user_id"] == user_id]
        
        for hive_id in user_hive_ids:
            if hive_id in test_hives:
                hive = test_hives[hive_id]
                if hive.get("current_streak", 0) >= 7:
                    milestones.append({
                        "type": "hive_week_streak",
                        "hive_name": hive["name"],
                        "achieved_at": datetime.utcnow()
                    })
    
    return milestones
