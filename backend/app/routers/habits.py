from fastapi import APIRouter, HTTPException, status, Depends, Query
from app.models.schemas import (
    Habit, HabitCreate, HabitUpdate, HabitWithLogs,
    HabitLog, HabitLogCreate, LogHabitRequest,
    InsightsResponse
)
from app.core.auth import get_current_user
from app.core.supabase import get_supabase_client
from app.core.config import settings
from typing import Dict, Any, List, Optional
from datetime import datetime, date, timedelta
import uuid

router = APIRouter()

# In-memory storage for test mode
test_habits = {}
test_logs = {}

def calculate_streak(logs: List[dict], target_date: date = None) -> int:
    """Calculate current streak from logs"""
    if not logs:
        return 0
    
    if target_date is None:
        target_date = date.today()
    
    # Sort logs by date descending
    sorted_logs = sorted(logs, key=lambda x: x['log_date'], reverse=True)
    
    streak = 0
    current_date = target_date
    
    for log in sorted_logs:
        log_date = log['log_date']
        if isinstance(log_date, str):
            log_date = date.fromisoformat(log_date)
        
        if log_date == current_date:
            streak += 1
            current_date = current_date - timedelta(days=1)
        elif log_date < current_date:
            break
    
    return streak

@router.get("/", response_model=List[HabitWithLogs])
async def get_habits(
    current_user: Dict[str, Any] = Depends(get_current_user),
    include_logs: bool = Query(False, description="Include recent logs"),
    days: int = Query(30, description="Number of days of logs to include")
):
    """Get all habits for current user"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        # Return test habits
        user_habits = [h for h in test_habits.values() if h["user_id"] == user_id]
        
        result = []
        for habit in user_habits:
            habit_with_logs = HabitWithLogs(**habit)
            
            if include_logs:
                # Get logs for this habit
                habit_logs = [l for l in test_logs.values() 
                             if l["habit_id"] == habit["id"]]
                habit_with_logs.recent_logs = [HabitLog(**l) for l in habit_logs[-days:]]
                habit_with_logs.current_streak = calculate_streak(habit_logs)
                
                # Calculate completion rate
                total_days = days
                completed_days = len(set(l["log_date"] for l in habit_logs))
                habit_with_logs.completion_rate = (completed_days / total_days) * 100 if total_days > 0 else 0
            
            result.append(habit_with_logs)
        
        return result
    
    try:
        supabase = get_supabase_client()
        
        # Get habits
        response = supabase.table("habits").select("*").eq("user_id", user_id).eq("is_active", True).execute()
        habits = response.data or []
        
        result = []
        for habit in habits:
            habit_with_logs = HabitWithLogs(**habit)
            
            if include_logs:
                # Get recent logs
                start_date = (date.today() - timedelta(days=days)).isoformat()
                logs_response = supabase.table("habit_logs").select("*").eq(
                    "habit_id", habit["id"]
                ).gte("log_date", start_date).execute()
                
                logs = logs_response.data or []
                habit_with_logs.recent_logs = [HabitLog(**l) for l in logs]
                habit_with_logs.current_streak = calculate_streak(logs)
                
                # Calculate completion rate
                completed_days = len(set(l["log_date"] for l in logs))
                habit_with_logs.completion_rate = (completed_days / days) * 100 if days > 0 else 0
            
            result.append(habit_with_logs)
        
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch habits: {str(e)}"
        )

@router.post("/", response_model=Habit)
async def create_habit(
    habit: HabitCreate,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Create a new habit"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        # Create test habit
        habit_id = str(uuid.uuid4())
        now = datetime.utcnow()
        new_habit = {
            "id": habit_id,
            "user_id": user_id,
            **habit.dict(),
            "is_active": True,
            "created_at": now.isoformat(),
            "updated_at": now.isoformat()
        }
        test_habits[habit_id] = new_habit
        # Return with proper datetime objects for Pydantic to serialize
        return Habit(
            id=habit_id,
            user_id=user_id,
            **habit.dict(),
            is_active=True,
            created_at=now,
            updated_at=now
        )
    
    try:
        supabase = get_supabase_client()
        habit_data = {
            "user_id": user_id,
            **habit.dict()
        }
        response = supabase.table("habits").insert(habit_data).execute()
        return Habit(**response.data[0])
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create habit: {str(e)}"
        )

@router.get("/{habit_id}", response_model=HabitWithLogs)
async def get_habit(
    habit_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
    include_logs: bool = Query(True)
):
    """Get a specific habit"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        if habit_id not in test_habits:
            raise HTTPException(status_code=404, detail="Habit not found")
        
        habit = test_habits[habit_id]
        if habit["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized")
        
        habit_with_logs = HabitWithLogs(**habit)
        
        if include_logs:
            habit_logs = [l for l in test_logs.values() if l["habit_id"] == habit_id]
            habit_with_logs.recent_logs = [HabitLog(**l) for l in habit_logs]
            habit_with_logs.current_streak = calculate_streak(habit_logs)
        
        return habit_with_logs
    
    try:
        supabase = get_supabase_client()
        response = supabase.table("habits").select("*").eq("id", habit_id).eq("user_id", user_id).single().execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Habit not found")
        
        habit_with_logs = HabitWithLogs(**response.data)
        
        if include_logs:
            logs_response = supabase.table("habit_logs").select("*").eq("habit_id", habit_id).execute()
            logs = logs_response.data or []
            habit_with_logs.recent_logs = [HabitLog(**l) for l in logs]
            habit_with_logs.current_streak = calculate_streak(logs)
        
        return habit_with_logs
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch habit: {str(e)}"
        )

@router.patch("/{habit_id}", response_model=Habit)
async def update_habit(
    habit_id: str,
    update: HabitUpdate,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Update a habit"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        if habit_id not in test_habits:
            raise HTTPException(status_code=404, detail="Habit not found")
        
        habit = test_habits[habit_id]
        if habit["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized")
        
        update_data = update.dict(exclude_unset=True)
        habit.update(update_data)
        habit["updated_at"] = datetime.utcnow()
        
        return Habit(**habit)
    
    try:
        supabase = get_supabase_client()
        update_data = update.dict(exclude_unset=True)
        update_data["updated_at"] = datetime.utcnow().isoformat()
        
        response = supabase.table("habits").update(update_data).eq("id", habit_id).eq("user_id", user_id).execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Habit not found")
        
        return Habit(**response.data[0])
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update habit: {str(e)}"
        )

@router.delete("/{habit_id}")
async def delete_habit(
    habit_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Delete (archive) a habit"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        if habit_id not in test_habits:
            raise HTTPException(status_code=404, detail="Habit not found")
        
        habit = test_habits[habit_id]
        if habit["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized")
        
        # Soft delete
        habit["is_active"] = False
        habit["updated_at"] = datetime.utcnow()
        
        return {"success": True, "message": "Habit archived"}
    
    try:
        supabase = get_supabase_client()
        
        # Soft delete by setting is_active to false
        response = supabase.table("habits").update({
            "is_active": False,
            "updated_at": datetime.utcnow().isoformat()
        }).eq("id", habit_id).eq("user_id", user_id).execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Habit not found")
        
        return {"success": True, "message": "Habit archived"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete habit: {str(e)}"
        )

@router.post("/{habit_id}/log", response_model=HabitLog)
async def log_habit(
    habit_id: str,
    log_data: HabitLogCreate,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Log a habit for today"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        if habit_id not in test_habits:
            raise HTTPException(status_code=404, detail="Habit not found")
        
        habit = test_habits[habit_id]
        if habit["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized")
        
        # Cap value at target
        value = min(log_data.value, habit["target_per_day"])
        
        log_id = str(uuid.uuid4())
        log_date = date.today()
        
        # Check for existing log
        existing = [l for l in test_logs.values() 
                   if l["habit_id"] == habit_id and l["log_date"] == log_date]
        
        if existing:
            # Update existing
            existing[0]["value"] = value
            existing[0]["created_at"] = datetime.utcnow()
            return HabitLog(**existing[0])
        
        new_log = {
            "id": log_id,
            "habit_id": habit_id,
            "user_id": user_id,
            "log_date": log_date,
            "value": value,
            "source": "api",
            "created_at": datetime.utcnow()
        }
        test_logs[log_id] = new_log
        return HabitLog(**new_log)
    
    try:
        supabase = get_supabase_client()
        
        # Call the log_habit RPC
        response = supabase.rpc("log_habit", {
            "p_habit_id": habit_id,
            "p_value": log_data.value
        }).execute()
        
        return HabitLog(**response.data)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to log habit: {str(e)}"
        )

@router.get("/{habit_id}/logs", response_model=List[HabitLog])
async def get_habit_logs(
    habit_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
    start_date: Optional[date] = None,
    end_date: Optional[date] = None
):
    """Get logs for a habit"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        if habit_id not in test_habits:
            raise HTTPException(status_code=404, detail="Habit not found")
        
        habit = test_habits[habit_id]
        if habit["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized")
        
        logs = [l for l in test_logs.values() if l["habit_id"] == habit_id]
        
        if start_date:
            logs = [l for l in logs if l["log_date"] >= start_date]
        if end_date:
            logs = [l for l in logs if l["log_date"] <= end_date]
        
        return [HabitLog(**l) for l in logs]
    
    try:
        supabase = get_supabase_client()
        
        query = supabase.table("habit_logs").select("*").eq("habit_id", habit_id).eq("user_id", user_id)
        
        if start_date:
            query = query.gte("log_date", start_date.isoformat())
        if end_date:
            query = query.lte("log_date", end_date.isoformat())
        
        response = query.execute()
        return [HabitLog(**l) for l in response.data]
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch logs: {str(e)}"
        )

@router.get("/insights/summary", response_model=InsightsResponse)
async def get_insights(
    current_user: Dict[str, Any] = Depends(get_current_user),
    days: int = Query(30, description="Number of days to analyze")
):
    """Get insights and statistics"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        # Calculate test insights
        user_habits = [h for h in test_habits.values() if h["user_id"] == user_id and h["is_active"]]
        
        current_streaks = {}
        year_comb = {}
        total_logs = 0
        total_possible = 0
        
        for habit in user_habits:
            habit_logs = [l for l in test_logs.values() if l["habit_id"] == habit["id"]]
            current_streaks[habit["name"]] = calculate_streak(habit_logs)
            
            # Year comb data (simplified)
            year_comb[habit["name"]] = len(habit_logs)
            
            total_logs += len(habit_logs)
            total_possible += days
        
        overall_completion = (total_logs / total_possible * 100) if total_possible > 0 else 0
        
        return InsightsResponse(
            overall_completion=overall_completion,
            active_habits=len(user_habits),
            current_streaks=current_streaks,
            year_comb=year_comb
        )
    
    try:
        # Implementation for production would query Supabase
        return InsightsResponse(
            overall_completion=0.0,
            active_habits=0,
            current_streaks={},
            year_comb={}
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch insights: {str(e)}"
        )