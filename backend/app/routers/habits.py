from fastapi import APIRouter, HTTPException, status, Depends, Query
from app.models.schemas import (
    Habit, HabitCreate, HabitUpdate, HabitWithLogs,
    HabitLog, HabitLogCreate, LogHabitRequest,
    HabitStreakSummary, HabitPerformance, InsightsResponse
)
from app.core.auth import get_current_user
from app.core.supabase import get_user_supabase_client, get_supabase_admin
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
        print(f"Getting habits for user: {user_id}")
        supabase = get_supabase_admin()

        # Get habits for the authenticated user using the service role to avoid
        # issues with expired caller tokens while still scoping to the caller's
        # user_id.
        response = (
            supabase
            .table("habits")
            .select("*")
            .eq("user_id", user_id)
            .eq("is_active", True)
            .order("created_at", desc=True)
            .execute()
        )

        if getattr(response, "error", None):
            raise Exception(response.error.get("message", "Unable to fetch habits"))

        habits = response.data or []
        print(f"Found {len(habits)} habits for user {user_id}")
        
        result = []
        for habit in habits:
            print(f"Processing habit: {habit['id']} - {habit['name']}")
            habit_with_logs = HabitWithLogs(**habit)

            if include_logs:
                # Get recent logs
                start_date = (date.today() - timedelta(days=days)).isoformat()
                print(f"Looking for logs since: {start_date}")
                logs_response = (
                    supabase
                    .table("habit_logs")
                    .select("*")
                    .eq("habit_id", habit["id"])
                    .eq("user_id", user_id)
                    .gte("log_date", start_date)
                    .order("log_date", desc=True)
                    .execute()
                )

                if getattr(logs_response, "error", None):
                    print(f"Error fetching logs: {logs_response.error}")
                    raise Exception(logs_response.error.get("message", "Unable to fetch logs"))

                logs = logs_response.data or []
                print(f"Found {len(logs)} logs for habit {habit['id']}: {logs}")

                # Convert to HabitLog objects and log the conversion
                habit_logs = []
                for l in logs:
                    habit_log = HabitLog(**l)
                    print(f"Converted log: {l} -> HabitLog(log_date={habit_log.log_date})")
                    habit_logs.append(habit_log)

                habit_with_logs.recent_logs = habit_logs
                habit_with_logs.current_streak = calculate_streak(logs)

                # Calculate completion rate
                completed_days = len(set(l["log_date"] for l in logs))
                habit_with_logs.completion_rate = (completed_days / days) * 100 if days > 0 else 0
                print(f"Habit {habit['id']} final logs count: {len(habit_with_logs.recent_logs or [])}")

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
        supabase = get_user_supabase_client(current_user)
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
        supabase = get_supabase_admin()
        response = (
            supabase
            .table("habits")
            .select("*")
            .eq("id", habit_id)
            .eq("user_id", user_id)
            .single()
            .execute()
        )

        if getattr(response, "error", None):
            raise Exception(response.error.get("message", "Unable to fetch habit"))
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Habit not found")
        
        habit_with_logs = HabitWithLogs(**response.data)
        
        if include_logs:
            logs_response = (
                supabase
                .table("habit_logs")
                .select("*")
                .eq("habit_id", habit_id)
                .eq("user_id", user_id)
                .order("log_date", desc=True)
                .execute()
            )

            if getattr(logs_response, "error", None):
                raise Exception(logs_response.error.get("message", "Unable to fetch logs"))
            
            logs = logs_response.data or []
            print(f"🔍 GET habit {habit_id} logs: {logs}")
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
        supabase = get_user_supabase_client(current_user)
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
        supabase = get_user_supabase_client(current_user)
        
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
        supabase = get_user_supabase_client(current_user)

        print(f"📝 Logging habit {habit_id} for user {user_id} with value {log_data.value}")
        # Use a fixed current UTC timestamp since server clock seems to be behind
        import time
        actual_utc_now = datetime.utcfromtimestamp(time.time())

        print(f"📝 Today's date (server): {date.today()}")
        print(f"📝 UTC now (datetime.utcnow): {datetime.utcnow()}")
        print(f"📝 UTC now (from time.time): {actual_utc_now}")

        current_utc = actual_utc_now.isoformat() + "Z"
        print(f"📝 Sending timestamp: {current_utc}")

        # Bypass the RPC and directly insert/update the log with correct date
        today_date = actual_utc_now.date().isoformat()
        print(f"📝 Using date: {today_date}")

        # Try to insert or update the habit log directly
        response = supabase.table("habit_logs").upsert({
            "habit_id": habit_id,
            "user_id": user_id,
            "log_date": today_date,
            "value": log_data.value,
            "source": "api",
            "notes": None
        }, on_conflict="habit_id,log_date").execute()

        print(f"📝 RPC response: {response}")
        print(f"📝 RPC data: {response.data}")
        print(f"📝 RPC error: {getattr(response, 'error', None)}")

        if getattr(response, "error", None):
            print(f"📝 Database error details: {response.error}")
            raise Exception(f"Database error: {response.error}")

        db_result = response.data
        if isinstance(db_result, list):
            if not db_result:
                raise HTTPException(status_code=500, detail="Habit log insert returned no data")
            db_result = db_result[0]

        if db_result is None:
            raise HTTPException(status_code=500, detail="Habit log insert returned empty payload")

        print(f"📝 Final result: {db_result}")
        return HabitLog(**db_result)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to log habit: {str(e)}"
        )


@router.delete("/{habit_id}/log")
async def delete_habit_log(
    habit_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
    log_date: Optional[date] = Query(None, description="Date of the log to delete (defaults to today)")
):
    """Delete a habit log for a specific day (defaults to today)."""
    user_id = current_user["id"]
    target_date = log_date or date.today()

    if settings.TEST_MODE:
        # Find matching logs and remove
        to_delete = [key for key, log in test_logs.items()
                     if log["habit_id"] == habit_id
                     and log["user_id"] == user_id
                     and log["log_date"] == target_date]

        if not to_delete:
            return {"success": False, "message": "No log found"}

        for key in to_delete:
            test_logs.pop(key, None)

        return {"success": True, "message": "Log removed"}

    try:
        supabase = get_user_supabase_client(current_user)

        response = supabase.table("habit_logs").delete().eq("habit_id", habit_id)
        response = response.eq("user_id", user_id).eq("log_date", target_date.isoformat()).execute()

        deleted = bool(response.data)
        return {"success": deleted, "message": "Log removed" if deleted else "No log found"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete habit log: {str(e)}"
        )

@router.get("/{habit_id}/logs", response_model=List[HabitLog])
async def get_habit_logs(
    habit_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
    start_date: Optional[str] = None,
    end_date: Optional[str] = None
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
        supabase = get_user_supabase_client(current_user)

        query = supabase.table("habit_logs").select("*").eq("habit_id", habit_id).eq("user_id", user_id)

        if start_date:
            # Parse ISO datetime string to date-only format for database comparison
            try:
                parsed_date = datetime.fromisoformat(start_date.replace('Z', '+00:00')).date()
                query = query.gte("log_date", parsed_date.isoformat())
            except ValueError:
                # If parsing fails, assume it's already in the right format
                query = query.gte("log_date", start_date)

        if end_date:
            try:
                parsed_date = datetime.fromisoformat(end_date.replace('Z', '+00:00')).date()
                query = query.lte("log_date", parsed_date.isoformat())
            except ValueError:
                query = query.lte("log_date", end_date)
        
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

    def build_response(habits: List[Dict[str, Any]], logs: List[Dict[str, Any]]) -> InsightsResponse:
        today = date.today()
        window_start = today - timedelta(days=days - 1)
        year_start = today - timedelta(days=365)

        habit_map = {habit["id"]: habit for habit in habits if habit.get("is_active", True)}
        active_habits = len(habit_map)

        logs_by_date: Dict[date, List[Dict[str, Any]]] = {}
        logs_by_habit: Dict[str, List[Dict[str, Any]]] = {hid: [] for hid in habit_map.keys()}

        for log in logs:
            log_date = log["log_date"]
            if isinstance(log_date, str):
                log_date = date.fromisoformat(log_date)

            if log["habit_id"] not in habit_map:
                continue

            logs_by_date.setdefault(log_date, []).append(log)
            logs_by_habit.setdefault(log["habit_id"], []).append({
                "log_date": log_date,
                "value": log.get("value", 1)
            })

        completed_today = len(logs_by_date.get(today, []))

        weekly_progress: List[int] = []
        for offset in range(6, -1, -1):
            day = today - timedelta(days=offset)
            weekly_progress.append(len(logs_by_date.get(day, [])))

        total_possible = active_habits * days
        completed_in_window = sum(
            1 for log in logs
            if log["habit_id"] in habit_map and isinstance(log["log_date"], str) and date.fromisoformat(log["log_date"]) >= window_start
        )
        overall_completion = (completed_in_window / total_possible * 100) if total_possible > 0 else 0

        streaks: List[HabitStreakSummary] = []
        best_perf: Optional[HabitPerformance] = None
        best_rate = -1.0

        for habit_id, habit in habit_map.items():
            habit_logs = logs_by_habit.get(habit_id, [])
            streak = calculate_streak(habit_logs, target_date=today)
            streaks.append(
                HabitStreakSummary(
                    habit_id=uuid.UUID(habit_id),
                    name=habit.get("name", ""),
                    emoji=habit.get("emoji"),
                    streak=streak
                )
            )

            # Completion rate for recent window
            recent_count = sum(
                1 for log in habit_logs
                if isinstance(log["log_date"], date) and log["log_date"] >= window_start
            )
            rate = (recent_count / days) * 100 if days > 0 else 0
            if rate > best_rate:
                best_rate = rate
                best_perf = HabitPerformance(
                    habit_id=uuid.UUID(habit_id),
                    name=habit.get("name", ""),
                    emoji=habit.get("emoji"),
                    completion_rate=rate
                )

        year_comb: Dict[str, int] = {}
        for log_date, entries in logs_by_date.items():
            if log_date >= year_start:
                year_comb[log_date.isoformat()] = len(entries)

        streaks.sort(key=lambda item: item.streak, reverse=True)

        return InsightsResponse(
            overall_completion=overall_completion,
            active_habits=active_habits,
            completed_today=completed_today,
            weekly_progress=weekly_progress,
            current_streaks=streaks,
            year_comb=year_comb,
            best_performing=best_perf
        )

    if settings.TEST_MODE:
        user_habits = [h for h in test_habits.values() if h["user_id"] == user_id and h.get("is_active", True)]
        user_logs = [l for l in test_logs.values() if l["user_id"] == user_id]
        return build_response(user_habits, user_logs)

    try:
        supabase = get_user_supabase_client(current_user)
        habits_response = supabase.table("habits").select("*").eq("user_id", user_id).eq("is_active", True).execute()
        logs_response = supabase.table("habit_logs").select("habit_id, log_date, value").eq("user_id", user_id).execute()

        return build_response(habits_response.data or [], logs_response.data or [])
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch insights: {str(e)}"
        )
