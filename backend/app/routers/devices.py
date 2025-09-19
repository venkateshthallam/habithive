from fastapi import APIRouter, HTTPException, status, Depends
from typing import Dict, Any
from pydantic import BaseModel, Field
from app.core.auth import get_current_user
from app.core.supabase import get_supabase_client

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
    user_id = current_user["id"]
    try:
        supabase = get_supabase_client()
        row = {
            "user_id": user_id,
            "apns_token": payload.apns_token,
            "environment": payload.environment,
            "device_model": payload.device_model,
            "app_version": payload.app_version,
        }
        # Upsert on unique(apns_token)
        response = supabase.table("device_tokens").upsert(row, on_conflict=("apns_token")).execute()
        return {"success": True, "id": (response.data or [{}])[0].get("id")}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to register device: {str(e)}"
        )

