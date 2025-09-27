from fastapi import APIRouter, HTTPException, status, Depends
from typing import List, Dict, Any
from pydantic import BaseModel, Field
from app.core.auth import get_current_user
from app.core.supabase import get_user_supabase_client

router = APIRouter()

class ContactHash(BaseModel):
    contact_hash: str = Field(..., description="sha256(pepper || e164)")
    display_name: str | None = None

class UploadContactsRequest(BaseModel):
    contacts: List[ContactHash]

@router.post("/upload")
async def upload_contacts(
    payload: UploadContactsRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Upload hashed contacts for matching."""
    user_id = current_user["id"]
    try:
        supabase = get_user_supabase_client(current_user)
        rows = [
            {
                "user_id": user_id,
                "contact_hash": c.contact_hash,
                "display_name": c.display_name,
            }
            for c in payload.contacts
        ]
        if not rows:
            return {"success": True, "inserted": 0}

        # Upsert on (user_id, contact_hash)
        response = supabase.table("contact_hashes").upsert(rows, on_conflict=("user_id,contact_hash")).execute()
        return {"success": True, "inserted": len(response.data or [])}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload contacts: {str(e)}"
        )

