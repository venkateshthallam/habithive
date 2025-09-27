from fastapi import APIRouter, HTTPException, status, Depends, Query
from app.models.schemas import (
    Hive, HiveCreate, HiveFromHabit, HiveDetail,
    HiveMember, HiveMemberDay, LogHiveRequest,
    HiveInvite, HiveInviteCreate, JoinHiveRequest
)
from app.core.auth import get_current_user
from app.core.supabase import get_user_supabase_client
from app.core.config import settings
from typing import Dict, Any, List, Optional
from datetime import datetime, date, timedelta
import uuid
import secrets

router = APIRouter()

# In-memory storage for test mode
test_hives = {}
test_hive_members = {}
test_hive_member_days = {}
test_hive_invites = {}

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

def generate_invite_code():
    """Generate a random invite code"""
    return secrets.token_hex(6)

@router.get("/", response_model=List[Hive])
async def get_hives(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Get all hives the user is a member of"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        # Get hives where user is a member
        user_hive_ids = [m["hive_id"] for m in test_hive_members.values() 
                        if m["user_id"] == user_id]
        
        hives = []
        for hive_id in user_hive_ids:
            if hive_id in test_hives:
                hive = test_hives[hive_id].copy()
                # Add member count
                member_count = len([m for m in test_hive_members.values() 
                                  if m["hive_id"] == hive_id])
                hive["member_count"] = member_count
                hives.append(Hive(**hive))
        
        return hives
    
    try:
        supabase = get_user_supabase_client(current_user)
        
        # Get hives where user is a member
        member_response = supabase.table("hive_members").select("hive_id").eq("user_id", user_id).execute()
        hive_ids = [m["hive_id"] for m in member_response.data]
        
        if not hive_ids:
            return []
        
        # Get hive details
        hives_response = supabase.table("hives").select("*, hive_members(count)").in_("id", hive_ids).execute()
        
        return [Hive(**h) for h in hives_response.data]
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch hives: {str(e)}"
        )

@router.post("/", response_model=Hive)
async def create_hive(
    hive: HiveCreate,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Create a new hive"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        hive_id = str(uuid.uuid4())
        new_hive = {
            "id": hive_id,
            "owner_id": user_id,
            **hive.dict(),
            "current_length": 0,
            "last_advanced_on": None,
            "created_at": datetime.utcnow()
        }
        test_hives[hive_id] = new_hive
        
        # Add owner as member
        member_id = str(uuid.uuid4())
        test_hive_members[member_id] = {
            "hive_id": hive_id,
            "user_id": user_id,
            "role": "owner",
            "joined_at": datetime.utcnow()
        }
        
        new_hive["member_count"] = 1
        return Hive(**new_hive)
    
    try:
        supabase = get_user_supabase_client(current_user)
        
        # Create hive
        hive_data = {
            "owner_id": user_id,
            **hive.dict()
        }
        hive_response = supabase.table("hives").insert(hive_data).execute()
        hive_id = hive_response.data[0]["id"]
        
        # Add owner as member
        supabase.table("hive_members").insert({
            "hive_id": hive_id,
            "user_id": user_id,
            "role": "owner"
        }).execute()
        
        return Hive(**hive_response.data[0])
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create hive: {str(e)}"
        )


@router.delete("/{hive_id}")
async def delete_hive(
    hive_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Delete a hive (owner only)."""
    user_id = current_user["id"]

    if settings.TEST_MODE:
        if hive_id not in test_hives:
            raise HTTPException(status_code=404, detail="Hive not found")

        hive = test_hives[hive_id]
        if hive["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Only the owner can delete the hive")

        # Remove hive and related data
        test_hives.pop(hive_id, None)
        to_delete_members = [key for key, member in test_hive_members.items() if member["hive_id"] == hive_id]
        for key in to_delete_members:
            test_hive_members.pop(key, None)

        to_delete_days = [key for key, day in test_hive_member_days.items() if day["hive_id"] == hive_id]
        for key in to_delete_days:
            test_hive_member_days.pop(key, None)

        to_delete_invites = [key for key, invite in test_hive_invites.items() if invite["hive_id"] == hive_id]
        for key in to_delete_invites:
            test_hive_invites.pop(key, None)

        return {"success": True, "message": "Hive deleted"}

    try:
        supabase = get_user_supabase_client(current_user)

        hive_response = supabase.table("hives").select("owner_id").eq("id", hive_id).single().execute()
        hive_data = hive_response.data

        if not hive_data:
            raise HTTPException(status_code=404, detail="Hive not found")

        if hive_data["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Only the owner can delete the hive")

        supabase.table("hives").delete().eq("id", hive_id).execute()

        return {"success": True, "message": "Hive deleted"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete hive: {str(e)}"
        )

@router.post("/from-habit", response_model=Hive)
async def create_hive_from_habit(
    request: HiveFromHabit,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Convert a habit to a hive"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        # Get the habit
        test_habits = get_test_habits()
        habit = None
        for h in test_habits.values():
            if h["id"] == str(request.habit_id) and h["user_id"] == user_id:
                habit = h
                break
        
        if not habit:
            raise HTTPException(status_code=404, detail="Habit not found")
        
        # Create hive from habit
        hive_id = str(uuid.uuid4())
        new_hive = {
            "id": hive_id,
            "name": request.name or habit["name"],
            "owner_id": user_id,
            "color_hex": habit["color_hex"],
            "type": habit["type"],
            "target_per_day": habit["target_per_day"],
            "rule": "all_must_complete",
            "threshold": None,
            "schedule_daily": habit["schedule_daily"],
            "schedule_weekmask": habit["schedule_weekmask"],
            "current_length": 0,
            "last_advanced_on": None,
            "created_at": datetime.utcnow()
        }
        test_hives[hive_id] = new_hive
        
        # Add owner as member
        member_id = str(uuid.uuid4())
        test_hive_members[member_id] = {
            "hive_id": hive_id,
            "user_id": user_id,
            "role": "owner",
            "joined_at": datetime.utcnow()
        }
        
        # Backfill logs if requested
        if request.backfill_days > 0:
            test_logs = get_test_logs()
            habit_logs = [l for l in test_logs.values() 
                         if l["habit_id"] == str(request.habit_id)]
            cutoff_date = date.today() - timedelta(days=request.backfill_days)
            
            for log in habit_logs:
                if log["log_date"] >= cutoff_date:
                    day_id = str(uuid.uuid4())
                    test_hive_member_days[day_id] = {
                        "hive_id": hive_id,
                        "user_id": user_id,
                        "day_date": log["log_date"],
                        "value": log["value"],
                        "done": log["value"] > 0
                    }
        
        new_hive["member_count"] = 1
        return Hive(**new_hive)
    
    try:
        supabase = get_user_supabase_client(current_user)
        
        # Call the create_hive_from_habit RPC
        response = supabase.rpc("create_hive_from_habit", {
            "p_habit_id": str(request.habit_id),
            "p_name": request.name,
            "p_backfill_days": request.backfill_days
        }).execute()
        
        hive_id = response.data
        
        # Get the created hive
        hive_response = supabase.table("hives").select("*").eq("id", hive_id).single().execute()
        
        return Hive(**hive_response.data)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create hive from habit: {str(e)}"
        )

@router.get("/{hive_id}", response_model=HiveDetail)
async def get_hive_detail(
    hive_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Get detailed hive information"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        if hive_id not in test_hives:
            raise HTTPException(status_code=404, detail="Hive not found")
        
        # Check if user is a member
        is_member = any(m["hive_id"] == hive_id and m["user_id"] == user_id 
                       for m in test_hive_members.values())
        if not is_member:
            raise HTTPException(status_code=403, detail="Not a member of this hive")
        
        hive = test_hives[hive_id].copy()
        
        # Get members
        members = []
        test_profiles = get_test_profiles()
        for m in test_hive_members.values():
            if m["hive_id"] == hive_id:
                member = HiveMember(**m)
                # Add profile info if available
                if m["user_id"] in test_profiles:
                    profile = test_profiles[m["user_id"]]
                    member.display_name = profile["display_name"]
                    member.avatar_url = profile["avatar_url"]
                members.append(member)
        
        # Get today's status
        today = date.today()
        today_status = {
            "complete_count": 0,
            "required_count": len(members),
            "members_done": []
        }
        
        for member in members:
            member_done = any(
                d["hive_id"] == hive_id and 
                d["user_id"] == member.user_id and 
                d["day_date"] == today and 
                d["done"]
                for d in test_hive_member_days.values()
            )
            if member_done:
                today_status["complete_count"] += 1
                today_status["members_done"].append(str(member.user_id))
        
        hive["member_count"] = len(members)
        
        return HiveDetail(
            **hive,
            members=members,
            today_status=today_status,
            recent_activity=[]
        )
    
    try:
        supabase = get_user_supabase_client(current_user)
        
        # Get hive
        hive_response = supabase.table("hives").select("*").eq("id", hive_id).single().execute()
        
        if not hive_response.data:
            raise HTTPException(status_code=404, detail="Hive not found")
        
        # Check membership
        member_check = supabase.table("hive_members").select("*").eq("hive_id", hive_id).eq("user_id", user_id).execute()
        
        if not member_check.data:
            raise HTTPException(status_code=403, detail="Not a member of this hive")
        
        # Get all members
        members_response = supabase.table("hive_members").select("*, profiles(display_name, avatar_url)").eq("hive_id", hive_id).execute()
        
        members = []
        for m in members_response.data:
            member = HiveMember(
                hive_id=m["hive_id"],
                user_id=m["user_id"],
                role=m["role"],
                joined_at=m["joined_at"],
                display_name=m.get("profiles", {}).get("display_name"),
                avatar_url=m.get("profiles", {}).get("avatar_url")
            )
            members.append(member)
        
        # Get today's status
        today = date.today().isoformat()
        today_status_response = supabase.table("hive_member_days").select("*").eq("hive_id", hive_id).eq("day_date", today).execute()
        
        today_status = {
            "complete_count": len([d for d in today_status_response.data if d["done"]]),
            "required_count": len(members),
            "members_done": [d["user_id"] for d in today_status_response.data if d["done"]]
        }
        
        # Get recent activity
        activity_response = supabase.table("activity_events").select("*").eq("hive_id", hive_id).order("created_at", desc=True).limit(20).execute()
        
        return HiveDetail(
            **hive_response.data,
            members=members,
            today_status=today_status,
            recent_activity=activity_response.data or []
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch hive details: {str(e)}"
        )

@router.post("/{hive_id}/invite", response_model=HiveInvite)
async def create_hive_invite(
    hive_id: str,
    invite: HiveInviteCreate,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Create an invite code for a hive"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        if hive_id not in test_hives:
            raise HTTPException(status_code=404, detail="Hive not found")
        
        hive = test_hives[hive_id]
        if hive["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Only owner can create invites")
        
        invite_id = str(uuid.uuid4())
        code = generate_invite_code()
        
        new_invite = {
            "id": invite_id,
            "hive_id": hive_id,
            "code": code,
            "created_by": user_id,
            "expires_at": datetime.utcnow() + timedelta(minutes=invite.ttl_minutes),
            "max_uses": invite.max_uses,
            "use_count": 0,
            "created_at": datetime.utcnow()
        }
        test_hive_invites[code] = new_invite
        
        return HiveInvite(**new_invite)
    
    try:
        supabase = get_user_supabase_client(current_user)
        
        # Call create_hive_invite RPC
        response = supabase.rpc("create_hive_invite", {
            "p_hive_id": hive_id,
            "p_ttl_minutes": invite.ttl_minutes,
            "p_max_uses": invite.max_uses
        }).execute()
        
        return HiveInvite(**response.data)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create invite: {str(e)}"
        )

@router.post("/join", response_model=dict)
async def join_hive(
    request: JoinHiveRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Join a hive using an invite code"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        if request.code not in test_hive_invites:
            raise HTTPException(status_code=400, detail="Invalid invite code")
        
        invite = test_hive_invites[request.code]
        
        # Check expiry
        if invite["expires_at"] < datetime.utcnow():
            raise HTTPException(status_code=400, detail="Invite has expired")
        
        # Check uses
        if invite["use_count"] >= invite["max_uses"]:
            raise HTTPException(status_code=400, detail="Invite has been used too many times")
        
        hive_id = invite["hive_id"]
        
        # Check if already a member
        is_member = any(m["hive_id"] == hive_id and m["user_id"] == user_id 
                       for m in test_hive_members.values())
        if is_member:
            return {"success": True, "hive_id": hive_id, "message": "Already a member"}
        
        # Check member count
        member_count = len([m for m in test_hive_members.values() 
                          if m["hive_id"] == hive_id])
        if member_count >= 10:
            raise HTTPException(status_code=400, detail="Hive is full (max 10 members)")
        
        # Add as member
        member_id = str(uuid.uuid4())
        test_hive_members[member_id] = {
            "hive_id": hive_id,
            "user_id": user_id,
            "role": "member",
            "joined_at": datetime.utcnow()
        }
        
        # Increment use count
        invite["use_count"] += 1
        
        return {"success": True, "hive_id": hive_id, "message": "Successfully joined hive"}
    
    try:
        supabase = get_user_supabase_client(current_user)
        
        # Call join_hive_with_code RPC
        response = supabase.rpc("join_hive_with_code", {
            "p_code": request.code
        }).execute()
        
        return {"success": True, "hive_id": response.data, "message": "Successfully joined hive"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to join hive: {str(e)}"
        )

@router.post("/{hive_id}/log", response_model=HiveMemberDay)
async def log_hive_day(
    hive_id: str,
    log: LogHiveRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Log completion for today in a hive"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        if hive_id not in test_hives:
            raise HTTPException(status_code=404, detail="Hive not found")
        
        # Check membership
        is_member = any(m["hive_id"] == hive_id and m["user_id"] == user_id 
                       for m in test_hive_members.values())
        if not is_member:
            raise HTTPException(status_code=403, detail="Not a member of this hive")
        
        today = date.today()
        
        # Check for existing log
        existing = None
        for day_id, day in test_hive_member_days.items():
            if day["hive_id"] == hive_id and day["user_id"] == user_id and day["day_date"] == today:
                existing = day_id
                break
        
        if existing:
            # Update existing
            test_hive_member_days[existing]["value"] = log.value
            test_hive_member_days[existing]["done"] = log.value > 0
            return HiveMemberDay(**test_hive_member_days[existing])
        
        # Create new log
        day_id = str(uuid.uuid4())
        new_day = {
            "hive_id": hive_id,
            "user_id": user_id,
            "day_date": today,
            "value": log.value,
            "done": log.value > 0
        }
        test_hive_member_days[day_id] = new_day
        
        return HiveMemberDay(**new_day)
    
    try:
        supabase = get_user_supabase_client(current_user)
        
        # Call log_hive_today RPC
        response = supabase.rpc("log_hive_today", {
            "p_hive_id": hive_id,
            "p_value": log.value
        }).execute()
        
        return HiveMemberDay(**response.data)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to log hive day: {str(e)}"
        )

@router.post("/{hive_id}/advance", response_model=dict)
async def advance_hive_day(
    hive_id: str,
    day: Optional[date] = None,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Check and advance hive streak for a day"""
    user_id = current_user["id"]
    
    if settings.TEST_MODE:
        if hive_id not in test_hives:
            raise HTTPException(status_code=404, detail="Hive not found")
        
        # Check membership
        is_member = any(m["hive_id"] == hive_id and m["user_id"] == user_id 
                       for m in test_hive_members.values())
        if not is_member:
            raise HTTPException(status_code=403, detail="Not a member of this hive")
        
        target_day = day or date.today()
        
        # Count members
        members = [m for m in test_hive_members.values() if m["hive_id"] == hive_id]
        required_count = len(members)
        
        # Count completions
        complete_count = 0
        for member in members:
            member_done = any(
                d["hive_id"] == hive_id and 
                d["user_id"] == member["user_id"] and 
                d["day_date"] == target_day and 
                d["done"]
                for d in test_hive_member_days.values()
            )
            if member_done:
                complete_count += 1
        
        # Check if all completed
        advanced = complete_count == required_count
        
        if advanced:
            hive = test_hives[hive_id]
            if not hive["last_advanced_on"] or hive["last_advanced_on"] < target_day:
                hive["current_length"] += 1
                hive["last_advanced_on"] = target_day
        
        return {
            "advanced": advanced,
            "complete_count": complete_count,
            "required_count": required_count
        }
    
    try:
        supabase = get_user_supabase_client(current_user)
        
        # Call advance_hive_day RPC
        response = supabase.rpc("advance_hive_day", {
            "p_hive_id": hive_id,
            "p_day": (day or date.today()).isoformat()
        }).execute()
        
        return response.data[0]
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to advance hive: {str(e)}"
        )
