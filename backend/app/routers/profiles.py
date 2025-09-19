from fastapi import APIRouter, HTTPException, status, Depends
from app.models.schemas import Profile, ProfileUpdate
from app.core.auth import get_current_user
from app.core.supabase import get_supabase_client
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
    
    if settings.TEST_MODE:
        # Return test profile
        if user_id not in test_profiles:
            test_profiles[user_id] = {
                "id": user_id,
                "display_name": f"Bee {user_id[:6]}",
                "avatar_url": None,
                "timezone": "America/New_York",
                "day_start_hour": 4,
                "theme": "honey",
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
        return Profile(**test_profiles[user_id])
    
    try:
        supabase = get_supabase_client()
        response = supabase.table("profiles").select("*").eq("id", user_id).single().execute()
        
        if not response.data:
            # Create default profile
            profile_data = {
                "id": user_id,
                "display_name": f"Bee {user_id[:6]}",
                "timezone": "America/New_York",
                "day_start_hour": 4,
                "theme": "honey"
            }
            response = supabase.table("profiles").insert(profile_data).execute()
        
        return Profile(**response.data)
    except Exception as e:
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
    
    if settings.TEST_MODE:
        # Update test profile
        if user_id not in test_profiles:
            test_profiles[user_id] = {
                "id": user_id,
                "display_name": f"Bee {user_id[:6]}",
                "avatar_url": None,
                "timezone": "America/New_York",
                "day_start_hour": 4,
                "theme": "honey",
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
        
        # Apply updates
        update_data = update.dict(exclude_unset=True)
        test_profiles[user_id].update(update_data)
        test_profiles[user_id]["updated_at"] = datetime.utcnow()
        
        return Profile(**test_profiles[user_id])
    
    try:
        supabase = get_supabase_client()
        update_data = update.dict(exclude_unset=True)
        update_data["updated_at"] = datetime.utcnow().isoformat()
        
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
    if settings.TEST_MODE:
        # Return test profile
        if user_id not in test_profiles:
            test_profiles[user_id] = {
                "id": user_id,
                "display_name": f"Bee {user_id[:6]}",
                "avatar_url": None,
                "timezone": "America/New_York",
                "day_start_hour": 4,
                "theme": "honey",
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
        return Profile(**test_profiles[user_id])
    
    try:
        supabase = get_supabase_client()
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