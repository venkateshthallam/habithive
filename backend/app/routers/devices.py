from fastapi import APIRouter, HTTPException, status, Depends
from typing import Dict, Any
from pydantic import BaseModel, Field
from app.core.auth import get_current_user
from app.core.supabase import get_user_supabase_client
from app.core.onesignal import onesignal_client

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
    try:
        # Register device with OneSignal to get player_id
        onesignal_response = await onesignal_client.create_device(
            device_token=payload.apns_token,
            device_type=0  # iOS
        )
        onesignal_player_id = onesignal_response.get("id")

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
        response = supabase.table("device_tokens").upsert(row, on_conflict=("apns_token")).execute()
        return {
            "success": True,
            "id": (response.data or [{}])[0].get("id"),
            "onesignal_player_id": onesignal_player_id
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to register device: {str(e)}"
        )
