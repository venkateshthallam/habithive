from fastapi import APIRouter, HTTPException, status, Depends
from app.models.schemas import PhoneAuthRequest, VerifyOTPRequest, AppleSignInRequest, AuthResponse
from app.core.config import settings
from app.core.auth import create_test_token, get_current_user
from app.core.supabase import get_supabase_client, get_supabase_admin
import uuid
from typing import Dict, Any

router = APIRouter()

@router.post("/send-otp", response_model=dict)
async def send_otp(request: PhoneAuthRequest):
    """Send OTP to phone number"""
    try:
        supabase = get_supabase_client()
        response = supabase.auth.sign_in_with_otp({
            "phone": request.phone
        })
        return {"success": True, "message": "OTP sent successfully"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to send OTP: {str(e)}"
        )

@router.post("/verify-otp", response_model=AuthResponse)
async def verify_otp(request: VerifyOTPRequest):
    """Verify OTP and return auth tokens"""
    try:
        supabase = get_supabase_client()
        response = supabase.auth.verify_otp({
            "phone": request.phone,
            "token": request.otp,
            "type": "sms"
        })
        
        return AuthResponse(
            access_token=response.session.access_token,
            refresh_token=response.session.refresh_token,
            user_id=response.user.id,
            phone=response.user.phone
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to verify OTP: {str(e)}"
        )

@router.post("/apple-signin", response_model=AuthResponse)
async def apple_signin(request: AppleSignInRequest):
    """Sign in with Apple ID token"""
    try:
        supabase = get_supabase_admin()

        # Use Supabase auth to verify and create/login user with Apple
        response = supabase.auth.sign_in_with_id_token({
            "provider": "apple",
            "token": request.id_token,
            "nonce": request.nonce
        })

        if not response.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Apple ID token"
            )

        # Profile should be created automatically by the trigger
        # But let's make sure it exists
        try:
            # First check if profile already exists
            existing_profile = supabase.table("profiles").select("id").eq("id", response.user.id).execute()

            if not existing_profile.data:
                # If no profile exists, the trigger might not have run
                # Try to create it manually with proper service role client
                display_name = response.user.user_metadata.get("full_name") or response.user.user_metadata.get("name") or "New Bee"

                supabase.table("profiles").insert({
                    "id": response.user.id,
                    "display_name": display_name,
                    "theme": "honey"
                }).execute()

        except Exception as profile_error:
            print(f"Profile creation warning: {profile_error}")
            # Don't fail the auth if profile creation fails

        # Get phone number from user metadata or use empty string
        phone = response.user.phone or ""

        return AuthResponse(
            access_token=response.session.access_token,
            refresh_token=response.session.refresh_token,
            user_id=response.user.id,
            phone=phone
        )

    except Exception as e:
        print(f"Apple sign in error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to authenticate with Apple: {str(e)}"
        )

@router.post("/refresh", response_model=AuthResponse)
async def refresh_token(refresh_token: str):
    """Refresh access token"""
    try:
        supabase = get_supabase_client()
        response = supabase.auth.refresh_session(refresh_token)
        
        return AuthResponse(
            access_token=response.session.access_token,
            refresh_token=response.session.refresh_token,
            user_id=response.user.id,
            phone=response.user.phone
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to refresh token: {str(e)}"
        )

@router.post("/signout")
async def signout(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Sign out current user"""
    try:
        # In production, revoke the token with Supabase
        return {"success": True, "message": "Signed out successfully"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to sign out: {str(e)}"
        )

@router.get("/me")
async def get_me(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Get current user info"""
    return current_user


@router.delete("/me")
async def delete_me(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Permanently delete the authenticated user's account and related data."""
    user_id = current_user["id"]

    if settings.TEST_MODE:
        # Best-effort cleanup of in-memory stores used during local development.
        try:
            from app.routers.profiles import test_profiles
            test_profiles.pop(user_id, None)

            from app.routers.habits import test_habits, test_logs
            for key, habit in list(test_habits.items()):
                if habit.get("user_id") == user_id:
                    test_habits.pop(key, None)
            for key, log in list(test_logs.items()):
                if log.get("user_id") == user_id:
                    test_logs.pop(key, None)

            from app.routers.hives import (
                test_hives,
                test_hive_members,
                test_hive_member_days,
                test_hive_invites,
            )

            owned_hive_ids = {
                hive_id for hive_id, hive in test_hives.items()
                if hive.get("owner_id") == user_id
            }

            # Remove hives the user owns.
            for hive_id in list(owned_hive_ids):
                test_hives.pop(hive_id, None)

            # Remove user memberships and collect associated hive IDs for cleanup.
            member_hive_ids = set()
            for key, member in list(test_hive_members.items()):
                if member.get("user_id") == user_id or member.get("hive_id") in owned_hive_ids:
                    member_hive_ids.add(member.get("hive_id"))
                    test_hive_members.pop(key, None)

            hive_ids_to_clean = owned_hive_ids.union(member_hive_ids)

            for key, day in list(test_hive_member_days.items()):
                if day.get("user_id") == user_id or day.get("hive_id") in hive_ids_to_clean:
                    test_hive_member_days.pop(key, None)

            for key, invite in list(test_hive_invites.items()):
                if invite.get("created_by") == user_id or invite.get("hive_id") in hive_ids_to_clean:
                    test_hive_invites.pop(key, None)

            from app.routers.activity import test_activity

            test_activity[:] = [
                event for event in test_activity
                if event.get("actor_id") != user_id and event.get("hive_id") not in hive_ids_to_clean
            ]
        except Exception:
            # Test mode cleanup is best-effort; ignore failures to avoid masking deletion.
            pass

        return {"success": True}

    try:
        supabase = get_supabase_admin()
        supabase.auth.admin.delete_user(user_id)
        return {"success": True}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete account: {str(e)}"
        )
