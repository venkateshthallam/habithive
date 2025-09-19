from fastapi import APIRouter, HTTPException, status, Depends
from app.models.schemas import PhoneAuthRequest, VerifyOTPRequest, AuthResponse
from app.core.config import settings
from app.core.auth import create_test_token, get_current_user
from app.core.supabase import get_supabase_client, get_supabase_admin
import uuid
from typing import Dict, Any

router = APIRouter()

@router.post("/send-otp", response_model=dict)
async def send_otp(request: PhoneAuthRequest):
    """Send OTP to phone number"""
    if settings.TEST_MODE:
        # In test mode, just return success
        return {
            "success": True,
            "message": f"Test mode: OTP would be sent to {request.phone}",
            "test_otp": "123456"  # For testing
        }
    
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
    if settings.TEST_MODE:
        # In test mode, accept any OTP and create test user
        if request.otp in ["123456", "000000"]:  # Test OTPs
            user_id = str(uuid.uuid4())
            
            # Create/update test profile
            if settings.SUPABASE_URL:
                try:
                    supabase = get_supabase_admin()
                    # Try to create profile
                    supabase.table("profiles").upsert({
                        "id": user_id,
                        "display_name": f"Bee {user_id[:6]}",
                        "theme": "honey"
                    }).execute()
                except:
                    pass  # Profile might already exist
            
            access_token = create_test_token(user_id, request.phone)
            return AuthResponse(
                access_token=access_token,
                refresh_token=access_token,  # Same for testing
                user_id=user_id,
                phone=request.phone
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid OTP (use 123456 or 000000 in test mode)"
            )
    
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

@router.post("/refresh", response_model=AuthResponse)
async def refresh_token(refresh_token: str):
    """Refresh access token"""
    if settings.TEST_MODE:
        # In test mode, just return the same token
        return AuthResponse(
            access_token=refresh_token,
            refresh_token=refresh_token,
            user_id=str(uuid.uuid4()),
            phone="+15555551234"
        )
    
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
    if settings.TEST_MODE:
        return {"success": True, "message": "Signed out successfully"}
    
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