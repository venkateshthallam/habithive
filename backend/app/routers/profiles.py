from fastapi import APIRouter, HTTPException, status, Depends
from app.models.schemas import Profile, ProfileUpdate
from app.core.auth import get_current_user
from app.core.supabase import get_user_supabase_client
from app.core.config import settings
from typing import Dict, Any
from datetime import datetime
import uuid

router = APIRouter()

# In-memory storage for test mode
test_profiles = {}

@router.get("/me", response_model=Profile)
async def get_my_profile(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Get current user's profile"""
    user_id = current_user["id"]
    print(f"Getting profile for user: {user_id}")
    
    try:
        supabase = get_user_supabase_client(current_user)
        print(f"Querying profile for user: {user_id}")

        response = supabase.table("profiles").select("*").eq("id", user_id).execute()
        print(f"Profile query response: {response}")

        if not response.data or len(response.data) == 0:
            print(f"No profile found for user {user_id}, creating default profile")

            # Use service role client for profile creation to bypass RLS
            from app.core.supabase import get_supabase_admin
            admin_supabase = get_supabase_admin()

            # Create default profile
            profile_data = {
                "id": user_id,
                "display_name": f"Bee {user_id[:6]}",
                "phone": current_user.get("phone"),
                "timezone": "America/New_York",
                "day_start_hour": 4,
                "theme": "honey"
            }
            print(f"Creating profile with data: {profile_data}")

            insert_response = admin_supabase.table("profiles").insert(profile_data).execute()
            print(f"Profile insert response: {insert_response}")

            if insert_response.data and len(insert_response.data) > 0:
                return Profile(**insert_response.data[0])
            else:
                raise Exception("Failed to create profile - no data returned")

        # Profile exists, return it
        profile_data = response.data[0] if isinstance(response.data, list) else response.data
        if profile_data.get("phone") is None and current_user.get("phone"):
            profile_data["phone"] = current_user.get("phone")
        print(f"Returning existing profile: {profile_data}")
        return Profile(**profile_data)

    except Exception as e:
        print(f"Profile endpoint error: {type(e).__name__}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch profile: {str(e)}"
        )

@router.patch("/me", response_model=Profile)
async def update_my_profile(
    update: ProfileUpdate,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Update current user's profile"""
    user_id = current_user["id"]
    
    try:
        supabase = get_user_supabase_client(current_user)
        update_data = update.dict(exclude_unset=True)
        update_data["updated_at"] = datetime.utcnow().isoformat()
        if "phone" in update_data:
            phone = update_data.get("phone")
            if phone:
                normalized = phone.strip()
                update_data["phone"] = normalized
            else:
                update_data["phone"] = None

        response = supabase.table("profiles").update(update_data).eq("id", user_id).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profile not found"
            )
        
        return Profile(**response.data[0])
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update profile: {str(e)}"
        )

@router.get("/{user_id}", response_model=Profile)
async def get_user_profile(
    user_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Get a specific user's profile (for hive members)"""
    try:
        supabase = get_user_supabase_client(current_user)
        response = supabase.table("profiles").select("*").eq("id", user_id).single().execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profile not found"
            )
        
        return Profile(**response.data)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch profile: {str(e)}"
        )
