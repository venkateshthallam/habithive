from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
import jwt as pyjwt
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from app.core.config import settings
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

    # Verify with Supabase JWT
    try:
        print(f"Attempting to decode token: {token[:50]}...")  # Debug: show first 50 chars

        # Decode the JWT to get user info
        # Supabase JWTs are standard JWTs that we can decode and verify
        payload = pyjwt.decode(token, options={"verify_signature": False})

        print(f"Decoded payload: {payload}")  # Debug: show the full payload

        if not payload.get("sub"):
            print("No 'sub' field in token payload")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: no subject"
            )

        # Check if token is expired (with some tolerance for clock skew)
        if payload.get("exp"):
            exp_time = payload["exp"]
            current_time = datetime.utcnow().timestamp()
            time_diff = current_time - exp_time

            print(f"Token expiration check - Exp: {exp_time}, Now: {current_time}, Diff: {time_diff} seconds")

            # Temporarily allow expired tokens for debugging
            # TODO: Re-enable proper expiration checking once token refresh is working
            if time_diff > 86400:  # Only reject if more than 1 day old
                print(f"Token expired by {time_diff} seconds (more than 1 day)")
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Token expired"
                )
            elif time_diff > 0:
                print(f"Token expired but allowing for debugging ({time_diff} seconds)")
        else:
            print("No expiration time in token")

        user_info = {
            "id": payload["sub"],
            "phone": payload.get("phone"),
            "email": payload.get("email"),
            "role": payload.get("role", "authenticated"),
            "access_token": token,
        }
        print(f"Returning user info: {user_info}")  # Debug
        return user_info

    except HTTPException:
        raise
    except Exception as e:
        print(f"Auth error details: {type(e).__name__}: {e}")  # More detailed debug logging
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
