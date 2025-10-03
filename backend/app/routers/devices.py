from fastapi import APIRouter, HTTPException, status, Depends
from typing import Dict, Any
from pydantic import BaseModel, Field
from app.core.auth import get_current_user
from app.core.supabase import get_user_supabase_client
from app.core.onesignal import onesignal_client
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

class RegisterDeviceRequest(BaseModel):
    apns_token: str
    environment: str = Field(default="prod")  # "dev" or "prod"
    device_model: str | None = None
    app_version: str | None = None

@router.post("/register")
async def register_device(
    payload: RegisterDeviceRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Register device for push notifications.
    Creates both APNs token record and OneSignal player ID.
    """
    user_id = current_user["id"]
    logger.info(f"📱 Device registration request from user: {user_id}")
    logger.info(f"📱 APNs Token: {payload.apns_token[:20]}...{payload.apns_token[-20:]}")
    logger.info(f"📱 Environment: {payload.environment}")

    try:
        # Register device with OneSignal to get player_id
        logger.info("🔄 Registering device with OneSignal...")

        # Map environment to OneSignal test_type
        # dev/sandbox = 1, prod/production = 2
        test_type = 1 if payload.environment == "dev" else 2

        onesignal_response = await onesignal_client.create_device(
            device_token=payload.apns_token,
            device_type=0,  # iOS
            test_type=test_type
        )
        onesignal_player_id = onesignal_response.get("id")
        logger.info(f"✅ OneSignal registration successful. Player ID: {onesignal_player_id}")

        # Store in Supabase
        supabase = get_user_supabase_client(current_user)
        row = {
            "user_id": user_id,
            "apns_token": payload.apns_token,
            "environment": payload.environment,
            "device_model": payload.device_model,
            "app_version": payload.app_version,
            "onesignal_player_id": onesignal_player_id,
        }
        # Upsert on unique(apns_token)
        logger.info("🔄 Storing device info in Supabase...")
        response = supabase.table("device_tokens").upsert(row, on_conflict=("apns_token")).execute()
        logger.info(f"✅ Device registration complete for user {user_id}")

        return {
            "success": True,
            "id": (response.data or [{}])[0].get("id"),
            "onesignal_player_id": onesignal_player_id
        }
    except Exception as e:
        logger.error(f"❌ Device registration failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to register device: {str(e)}"
        )
