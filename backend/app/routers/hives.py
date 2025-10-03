from fastapi import APIRouter, HTTPException, status, Depends, Query, Response
from app.models.schemas import (
    Hive, HiveCreate, HiveUpdate, HiveFromHabit,
    HiveMember, HiveMemberDay, LogHiveRequest,
    HiveInvite, HiveInviteCreate, JoinHiveRequest,
    HiveDetail, HiveMemberStatus, HiveTodaySummary,
    HiveOverviewResponse, HiveLeaderboardEntry, HiveHeatmapDay,
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

@router.get("/", response_model=HiveOverviewResponse)
async def get_hives(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Get all hives the user is a member of"""
    user_id = current_user["id"]

    if settings.TEST_MODE:
        # Get hives where user is an active member
        user_hive_ids = [m["hive_id"] for m in test_hive_members.values()
                         if m["user_id"] == user_id and m.get("is_active", True)]

        hives: List[Hive] = []
        for hive_id in user_hive_ids:
            if hive_id in test_hives:
                hive = test_hives[hive_id].copy()
                hive.setdefault("current_streak", hive.get("current_streak", 0))
                hive.setdefault("longest_streak", hive.get("longest_streak", 0))
                hive.setdefault("invite_code", hive.get("invite_code", generate_invite_code()))
                member_count = len([
                    m for m in test_hive_members.values()
                    if m["hive_id"] == hive_id and m.get("is_active", True)
                ])
                hive["member_count"] = member_count
                hives.append(Hive(**hive))

        return HiveOverviewResponse(hives=hives, leaderboard=[])

    try:
        supabase = get_user_supabase_client(current_user)

        # Get hives where user is a member
        member_response = (
            supabase
            .table("hive_members")
            .select("hive_id,user_id,role")
            .eq("user_id", user_id)
            .eq("is_active", True)
            .execute()
        )

        memberships = member_response.data or []
        hive_ids = [m["hive_id"] for m in memberships]

        if not hive_ids:
            return HiveOverviewResponse(hives=[], leaderboard=[])

        # Get hive details
        hives_response = (
            supabase
            .table("hives")
            .select("*")
            .in_("id", hive_ids)
            .eq("is_active", True)
            .order("updated_at", desc=True)
            .execute()
        )

        hive_rows = hives_response.data or []

        # Gather member roster across these hives
        members_response = (
            supabase
            .table("hive_members")
            .select("hive_id,user_id,role")
            .in_("hive_id", hive_ids)
            .eq("is_active", True)
            .execute()
        )
        member_rows = members_response.data or []

        # Fetch display info for members
        member_user_ids = list({row["user_id"] for row in member_rows})
        profiles_lookup: Dict[str, Dict[str, Any]] = {}
        if member_user_ids:
            profiles_response = (
                supabase
                .table("profiles")
                .select("id, display_name, avatar_url")
                .in_("id", member_user_ids)
                .execute()
            )
            profiles_lookup = {row["id"]: row for row in (profiles_response.data or [])}

        # Resolve the user's local day once to use across all hives
        user_day_response = supabase.rpc("user_local_date", {"p_user": str(user_id)}).execute()
        if getattr(user_day_response, "error", None):
            raise Exception(user_day_response.error.get("message", "Unable to resolve user day"))
        user_day_iso = user_day_response.data

        day_response = (
            supabase
            .table("hive_member_days")
            .select("hive_id,user_id,value,done")
            .in_("hive_id", hive_ids)
            .eq("day_date", user_day_iso)
            .execute()
        )
        day_rows = day_response.data or []

        # Pre-group data for efficiency
        members_by_hive: Dict[str, List[Dict[str, Any]]] = {}
        for row in member_rows:
            members_by_hive.setdefault(row["hive_id"], []).append(row)

        day_by_hive: Dict[str, Dict[str, Dict[str, Any]]] = {}
        for row in day_rows:
            hive_id = row["hive_id"]
            user_key = row["user_id"]
            day_by_hive.setdefault(hive_id, {})[user_key] = row

        leaderboard_map: Dict[str, Dict[str, Any]] = {}
        hives: List[Hive] = []

        for raw in hive_rows:
            hive_id = raw["id"]
            target = raw.get("target_per_day") or 1

            roster = members_by_hive.get(hive_id, [])
            member_count = len(roster)
            raw["member_count"] = member_count

            todays_entries = day_by_hive.get(hive_id, {})
            completed = partial = 0
            completion_total = 0.0

            for member in roster:
                user_key = member["user_id"]
                day_entry = todays_entries.get(user_key)
                raw_value = 0
                if day_entry is not None:
                    raw_value = int(day_entry.get("value", 0) or 0)

                if raw_value >= target:
                    completed += 1
                elif raw_value > 0:
                    partial += 1

                if target > 0:
                    completion_total += min(raw_value / target, 1.0)

                board = leaderboard_map.setdefault(
                    str(user_key),
                    {
                        "user_id": user_key,
                        "completed_today": 0,
                        "total_hives": 0,
                    },
                )
                board["total_hives"] += 1
                if raw_value >= target:
                    board["completed_today"] += 1

            if member_count:
                raw["avg_completion"] = (completion_total / member_count) * 100
            else:
                raw["avg_completion"] = 0.0

            raw.setdefault("current_streak", raw.get("current_length"))
            raw.setdefault("longest_streak", raw.get("current_streak"))
            raw.setdefault("updated_at", raw.get("updated_at", raw.get("created_at")))

            hives.append(Hive(**raw))

        leaderboard: List[HiveLeaderboardEntry] = []
        for stats in leaderboard_map.values():
            user_key = str(stats["user_id"])
            profile = profiles_lookup.get(user_key, {})
            leaderboard.append(
                HiveLeaderboardEntry(
                    user_id=uuid.UUID(user_key),
                    display_name=profile.get("display_name", "Bee"),
                    avatar_url=profile.get("avatar_url"),
                    completed_today=int(stats["completed_today"]),
                    total_hives=int(stats["total_hives"]),
                )
            )

        leaderboard.sort(key=lambda entry: (-entry.completed_today, entry.display_name.lower()))
        leaderboard = leaderboard[:5]

        return HiveOverviewResponse(hives=hives, leaderboard=leaderboard)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch hives: {str(e)}"
        )


@router.get("/{hive_id}", response_model=HiveDetail)
async def get_hive_detail(
    hive_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Return an enriched hive snapshot for the detail screen."""
    user_id = current_user["id"]

    if settings.TEST_MODE:
        if hive_id not in test_hives:
            raise HTTPException(status_code=404, detail="Hive not found")

        hive = test_hives[hive_id].copy()

        members_raw = [
            m for m in test_hive_members.values()
            if m["hive_id"] == hive_id and m.get("is_active", True)
        ]

        if not any(m["user_id"] == user_id for m in members_raw):
            raise HTTPException(status_code=403, detail="Not a member of this hive")

        today = date.today()
        target = hive.get("target_per_day", 1)

        member_status: List[HiveMemberStatus] = []
        completed = partial = pending = 0
        completion_total = 0.0

        for member in members_raw:
            profile = get_test_profiles().get(member["user_id"], {})
            day_entry = next((d for d in test_hive_member_days.values()
                              if d["hive_id"] == hive_id and d["user_id"] == member["user_id"]
                              and d["day_date"] == today), None)
            raw_value = day_entry.get("value", 0) if day_entry else 0
            value = int(raw_value)
            if value >= target:
                status_key = "completed"
                completed += 1
            elif value > 0:
                status_key = "partial"
                partial += 1
            else:
                status_key = "pending"
                pending += 1

            completion_total += min(value / target, 1.0) if target > 0 else 0

            member_status.append(
                HiveMemberStatus(
                    hive_id=hive_id,
                    user_id=member["user_id"],
                    role=member.get("role", "member"),
                    joined_at=member["joined_at"],
                    left_at=member.get("left_at"),
                    is_active=member.get("is_active", True),
                    display_name=profile.get("display_name"),
                    avatar_url=profile.get("avatar_url"),
                    status=status_key,  # type: ignore[arg-type]
                    value=value,
                    target_per_day=target,
                )
            )

        total_members = len(member_status)
        avg_completion = (completion_total / total_members) * 100 if total_members else 0.0

        today_summary = HiveTodaySummary(
            completed=completed,
            partial=partial,
            pending=pending,
            total=total_members,
            completion_rate=avg_completion,
        )

        hive.setdefault("current_streak", hive.get("current_length", 0))
        hive.setdefault("longest_streak", hive.get("current_streak", 0))
        hive.setdefault("member_count", total_members)
        hive.setdefault("invite_code", hive.get("invite_code", ""))
        hive.setdefault("updated_at", hive.get("updated_at", hive.get("created_at")))

        # Build heatmap for last 30 days
        heatmap: List[HiveHeatmapDay] = []
        for day_offset in range(29, -1, -1):
            day_date = today - timedelta(days=day_offset)
            day_entries = [
                d for d in test_hive_member_days.values()
                if d["hive_id"] == hive_id and d["day_date"] == day_date
            ]
            completed = sum(1 for d in day_entries if d.get("value", 0) >= target)
            ratio = completed / total_members if total_members > 0 else 0.0
            heatmap.append(HiveHeatmapDay(
                date=day_date,
                completion_ratio=ratio,
                completed_count=completed,
                total_count=total_members
            ))

        return HiveDetail(
            **hive,
            avg_completion=avg_completion,
            today_summary=today_summary,
            members=member_status,
            recent_activity=[],
            heatmap=heatmap,
        )

    try:
        supabase = get_user_supabase_client(current_user)

        hive_response = (
            supabase
            .table("hives")
            .select("*")
            .eq("id", hive_id)
            .eq("is_active", True)
            .single()
            .execute()
        )

        if not hive_response.data:
            raise HTTPException(status_code=404, detail="Hive not found")

        # Confirm membership
        membership_check = (
            supabase
            .table("hive_members")
            .select("hive_id")
            .eq("hive_id", hive_id)
            .eq("user_id", user_id)
            .eq("is_active", True)
            .limit(1)
            .execute()
        )

        if not membership_check.data:
            raise HTTPException(status_code=403, detail="Not a member of this hive")

        # Get hive members
        members_response = (
            supabase
            .table("hive_members")
            .select("*")
            .eq("hive_id", hive_id)
            .eq("is_active", True)
            .execute()
        )

        members_data = members_response.data or []

        # Get profiles for members separately
        if members_data:
            user_ids = [member["user_id"] for member in members_data]
            profiles_response = (
                supabase
                .table("profiles")
                .select("id, display_name, avatar_url")
                .in_("id", user_ids)
                .execute()
            )
            profiles_lookup = {p["id"]: p for p in (profiles_response.data or [])}

            # Add profile info to members
            for member in members_data:
                member["profiles"] = profiles_lookup.get(member["user_id"], {})
        member_count = len(members_data)

        today_iso = date.today().isoformat()
        day_response = (
            supabase
            .table("hive_member_days")
            .select("user_id,value")
            .eq("hive_id", hive_id)
            .eq("day_date", today_iso)
            .execute()
        )
        day_lookup = {item["user_id"]: item for item in (day_response.data or [])}

        target = hive_response.data.get("target_per_day", 1) or 1

        member_status: List[HiveMemberStatus] = []
        completed = partial = pending = 0
        completion_total = 0.0

        for entry in members_data:
            raw_value = 0
            if day_lookup.get(entry["user_id"]):
                raw_value = day_lookup[entry["user_id"]].get("value", 0) or 0
            value = int(raw_value)

            if value >= target:
                status_key = "completed"
                completed += 1
            elif value > 0:
                status_key = "partial"
                partial += 1
            else:
                status_key = "pending"
                pending += 1

            completion_total += min(value / target, 1.0) if target > 0 else 0

            profile = entry.get("profiles") or {}
            member_status.append(
                HiveMemberStatus(
                    hive_id=entry["hive_id"],
                    user_id=entry["user_id"],
                    role=entry.get("role", "member"),
                    joined_at=entry["joined_at"],
                    left_at=entry.get("left_at"),
                    is_active=entry.get("is_active", True),
                    display_name=profile.get("display_name"),
                    avatar_url=profile.get("avatar_url"),
                    status=status_key,  # type: ignore[arg-type]
                    value=value,
                    target_per_day=target,
                )
            )

        total_members = len(member_status)
        today_completion = (completion_total / total_members) * 100 if total_members else 0.0

        today_summary = HiveTodaySummary(
            completed=completed,
            partial=partial,
            pending=pending,
            total=total_members,
            completion_rate=today_completion,
        )

        seven_days_ago = (date.today() - timedelta(days=6)).isoformat()
        hive_days_response = (
            supabase
            .table("hive_days")
            .select("complete_count, required_count")
            .eq("hive_id", hive_id)
            .gte("day_date", seven_days_ago)
            .order("day_date", desc=True)
            .limit(7)
            .execute()
        )

        ratios = []
        for row in hive_days_response.data or []:
            required = row.get("required_count") or 0
            complete = row.get("complete_count") or 0
            if required > 0:
                ratios.append(min(complete / required, 1.0))

        avg_completion = (sum(ratios) / len(ratios)) * 100 if ratios else today_completion

        activity_response = (
            supabase
            .table("activity_events")
            .select("*")
            .eq("hive_id", hive_id)
            .order("created_at", desc=True)
            .limit(20)
            .execute()
        )

        hive_row = hive_response.data
        hive_row.setdefault("current_streak", hive_row.get("current_length"))
        hive_row.setdefault("longest_streak", hive_row.get("current_streak"))
        hive_row.setdefault("member_count", member_count)
        hive_row.setdefault("invite_code", hive_row.get("invite_code"))
        hive_row.setdefault("updated_at", hive_row.get("updated_at", hive_row.get("created_at")))

        # Build heatmap for last 30 days
        thirty_days_ago = (date.today() - timedelta(days=29)).isoformat()
        heatmap_response = (
            supabase
            .table("hive_member_days")
            .select("day_date,value,user_id")
            .eq("hive_id", hive_id)
            .gte("day_date", thirty_days_ago)
            .execute()
        )

        heatmap_data = heatmap_response.data or []

        # Group by date
        days_map: Dict[str, List[int]] = {}
        for entry in heatmap_data:
            day_str = entry["day_date"]
            value = entry.get("value", 0) or 0
            days_map.setdefault(day_str, []).append(value)

        # Build heatmap with all 30 days
        heatmap: List[HiveHeatmapDay] = []
        for day_offset in range(29, -1, -1):
            day_date = date.today() - timedelta(days=day_offset)
            day_str = day_date.isoformat()
            values = days_map.get(day_str, [])
            completed = sum(1 for v in values if v >= target)
            ratio = completed / member_count if member_count > 0 else 0.0
            heatmap.append(HiveHeatmapDay(
                date=day_date,
                completion_ratio=ratio,
                completed_count=completed,
                total_count=member_count
            ))

        return HiveDetail(
            **hive_row,
            avg_completion=avg_completion,
            today_summary=today_summary,
            members=member_status,
            recent_activity=activity_response.data or [],
            heatmap=heatmap,
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"Hive detail error for hive_id {hive_id}: {type(e).__name__}: {e}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch hive details: {str(e)}"
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
        payload = hive.dict()
        new_hive = {
            "id": hive_id,
            "owner_id": user_id,
            **payload,
            "current_streak": 0,
            "longest_streak": 0,
            "last_advanced_on": None,
            "invite_code": generate_invite_code(),
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        test_hives[hive_id] = new_hive

        # Add owner as member
        member_id = str(uuid.uuid4())
        test_hive_members[member_id] = {
            "hive_id": hive_id,
            "user_id": user_id,
            "role": "owner",
            "joined_at": datetime.utcnow(),
            "is_active": True
        }

        new_hive["member_count"] = 1
        return Hive(**new_hive)

    try:
        supabase = get_user_supabase_client(current_user)

        # Create hive
        hive_payload = hive.dict(exclude_unset=True)
        hive_data = {
            **hive_payload,
            "owner_id": user_id,
        }
        hive_response = supabase.table("hives").insert(hive_data).execute()
        hive_row = hive_response.data[0]
        hive_id = hive_row["id"]

        # Add owner as member
        supabase.table("hive_members").insert({
            "hive_id": hive_id,
            "user_id": user_id,
            "role": "owner"
        }).execute()

        hive_row["member_count"] = 1
        return Hive(**hive_row)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create hive: {str(e)}"
        )


@router.patch("/{hive_id}", response_model=Hive)
async def update_hive(
    hive_id: str,
    updates: HiveUpdate,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Update hive settings (owner only)."""
    user_id = current_user["id"]

    if settings.TEST_MODE:
        if hive_id not in test_hives:
            raise HTTPException(status_code=404, detail="Hive not found")

        hive = test_hives[hive_id]
        if hive["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Only the owner can update the hive")

        payload = updates.dict(exclude_unset=True)
        for key, value in payload.items():
            hive[key] = value
        hive["updated_at"] = datetime.utcnow()
        test_hives[hive_id] = hive
        hive["member_count"] = len([
            m for m in test_hive_members.values()
            if m["hive_id"] == hive_id and m.get("is_active", True)
        ])
        return Hive(**hive)

    try:
        supabase = get_user_supabase_client(current_user)

        hive_response = supabase.table("hives").select("owner_id").eq("id", hive_id).single().execute()
        hive_data = hive_response.data

        if not hive_data:
            raise HTTPException(status_code=404, detail="Hive not found")

        if hive_data["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Only the owner can update the hive")

        update_data = updates.dict(exclude_unset=True)
        if not update_data:
            current = supabase.table("hives").select("*").eq("id", hive_id).single().execute().data
            current["member_count"] = getattr(
                supabase.table("hive_members").select("user_id", count='exact').eq("hive_id", hive_id).eq("is_active", True).execute(),
                "count",
                0,
            )
            return Hive(**current)

        update_data["updated_at"] = datetime.utcnow().isoformat()

        response = supabase.table("hives").update(update_data).eq("id", hive_id).execute()
        if not response.data:
            raise HTTPException(status_code=404, detail="Hive not found")

        updated_row = response.data[0]
        member_count_resp = (
            supabase
            .table("hive_members")
            .select("user_id", count='exact')
            .eq("hive_id", hive_id)
            .eq("is_active", True)
            .execute()
        )
        updated_row["member_count"] = getattr(member_count_resp, "count", None) or 0

        return Hive(**updated_row)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update hive: {str(e)}"
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

        return Response(status_code=status.HTTP_204_NO_CONTENT)

    try:
        supabase = get_user_supabase_client(current_user)

        hive_response = supabase.table("hives").select("owner_id").eq("id", hive_id).single().execute()
        hive_data = hive_response.data

        if not hive_data:
            raise HTTPException(status_code=404, detail="Hive not found")

        if hive_data["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Only the owner can delete the hive")

        supabase.table("hives").delete().eq("id", hive_id).execute()

        return Response(status_code=status.HTTP_204_NO_CONTENT)
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
            "description": None,
            "owner_id": user_id,
            "emoji": habit.get("emoji"),
            "color_hex": habit["color_hex"],
            "type": habit["type"],
            "target_per_day": habit["target_per_day"],
            "rule": "all_must_complete",
            "threshold": None,
            "schedule_daily": habit["schedule_daily"],
            "schedule_weekmask": habit["schedule_weekmask"],
            "max_members": 10,
            "current_streak": 0,
            "longest_streak": 0,
            "last_advanced_on": None,
            "invite_code": generate_invite_code(),
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        test_hives[hive_id] = new_hive

        # Add owner as member
        member_id = str(uuid.uuid4())
        test_hive_members[member_id] = {
            "hive_id": hive_id,
            "user_id": user_id,
            "role": "owner",
            "joined_at": datetime.utcnow(),
            "is_active": True
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
        
        hive_row = hive_response.data
        hive_row["member_count"] = getattr(
            supabase.table("hive_members").select("user_id", count='exact').eq("hive_id", hive_id).eq("is_active", True).execute(),
            "count",
            0,
        )

        return Hive(**hive_row)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create hive from habit: {str(e)}"
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
        if hive_id in test_hives:
            test_hives[hive_id]["invite_code"] = code

        return HiveInvite(**new_invite)
    
    try:
        supabase = get_user_supabase_client(current_user)

        # Call create_hive_invite RPC
        response = supabase.rpc("create_hive_invite", {
            "p_hive_id": hive_id,
            "p_ttl_minutes": invite.ttl_minutes,
            "p_max_uses": invite.max_uses
        }).execute()

        invite_row = response.data

        # Also update the hive's default invite code for quick sharing
        supabase.table("hives").update({
            "invite_code": invite_row["code"],
            "updated_at": datetime.utcnow().isoformat()
        }).eq("id", hive_id).execute()

        return HiveInvite(**invite_row)
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


@router.post("/{hive_id}/leave", response_model=dict)
async def leave_hive(
    hive_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Leave a hive as a member."""
    user_id = current_user["id"]

    if settings.TEST_MODE:
        membership_items = [
            (key, member)
            for key, member in test_hive_members.items()
            if member["hive_id"] == hive_id and member["user_id"] == user_id and member.get("is_active", True)
        ]

        if not membership_items:
            raise HTTPException(status_code=404, detail="Membership not found")

        key, member = membership_items[0]
        if member.get("role") == "owner":
            raise HTTPException(status_code=403, detail="Transfer ownership before leaving the hive")

        test_hive_members[key]["is_active"] = False
        test_hive_members[key]["left_at"] = datetime.utcnow()
        return {"success": True}

    try:
        supabase = get_user_supabase_client(current_user)

        membership = (
            supabase
            .table("hive_members")
            .select("role")
            .eq("hive_id", hive_id)
            .eq("user_id", user_id)
            .eq("is_active", True)
            .execute()
        )

        if not membership.data:
            raise HTTPException(status_code=404, detail="Membership not found")

        member_row = membership.data[0]

        if member_row.get("role") == "owner":
            raise HTTPException(status_code=403, detail="Transfer ownership before leaving the hive")

        supabase.table("hive_members").update({
            "is_active": False,
            "left_at": datetime.utcnow().isoformat()
        }).eq("hive_id", hive_id).eq("user_id", user_id).execute()

        return {"success": True}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to leave hive: {str(e)}"
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

        membership = (
            supabase
            .table("hive_members")
            .select("role")
            .eq("hive_id", hive_id)
            .eq("user_id", user_id)
            .eq("is_active", True)
            .execute()
        )

        if not membership.data:
            raise HTTPException(status_code=403, detail="Not a member of this hive")

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
        members = [
            m for m in test_hive_members.values()
            if m["hive_id"] == hive_id and m.get("is_active", True)
        ]
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
                hive["current_streak"] = hive.get("current_streak", 0) + 1
                hive["longest_streak"] = max(hive.get("longest_streak", 0), hive["current_streak"])
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
