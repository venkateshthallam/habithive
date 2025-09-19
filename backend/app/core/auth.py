from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from app.core.config import settings
from app.core.supabase import get_supabase_client
import uuid

security = HTTPBearer()

def create_test_token(user_id: str, phone: str) -> str:
    """Create a test JWT token for development"""
    payload = {
        "sub": user_id,
        "phone": phone,
        "exp": datetime.utcnow() + timedelta(days=7),
        "iat": datetime.utcnow(),
        "role": "authenticated"
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm="HS256")

def verify_test_token(token: str) -> Dict[str, Any]:
    """Verify test JWT token"""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=["HS256"])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token"
        )

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """Get current user from JWT token"""
    token = credentials.credentials
    
    if settings.TEST_MODE:
        # In test mode, decode our test JWT
        try:
            payload = verify_test_token(token)
            return {
                "id": payload["sub"],
                "phone": payload.get("phone"),
                "role": payload.get("role", "authenticated")
            }
        except:
            # Allow test user if token is "test-token"
            if token == "test-token":
                return {
                    "id": str(uuid.uuid4()),
                    "phone": "+15555551234",
                    "role": "authenticated"
                }
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token"
            )
    
    # In production, verify with Supabase
    try:
        supabase = get_supabase_client()
        user = supabase.auth.get_user(token)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token"
            )
        return {
            "id": user.user.id,
            "phone": user.user.phone,
            "email": user.user.email,
            "role": user.user.role
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Authentication failed: {str(e)}"
        )

async def get_optional_user(credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)) -> Optional[Dict[str, Any]]:
    """Get current user if authenticated, otherwise None"""
    if not credentials:
        return None
    try:
        return await get_current_user(credentials)
    except:
        return None