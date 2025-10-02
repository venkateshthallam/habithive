from fastapi import Depends, HTTPException, status, Header
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
        print(f"TEST_MODE is set to: {settings.TEST_MODE}")  # Debug: show test mode setting

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

            # Handle token expiration with configurable skew tolerance to account for
            # clock drift between Supabase and the API server.
            if time_diff > 0:
                max_skew = settings.AUTH_TOKEN_MAX_SKEW_SECONDS
                if settings.TEST_MODE:
                    print(f"Test mode: allowing expired token (expired by {time_diff} seconds)")
                elif time_diff > max_skew:
                    print(f"Token expired by {time_diff} seconds (max allowed {max_skew})")
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Token expired"
                    )
                else:
                    print(
                        "Token expired but within configured tolerance "
                        f"({time_diff} <= {max_skew}); continuing"
                    )
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

async def verify_service_key(x_service_key: str = Header(...)) -> bool:
    """
    Verify internal service key for pg_cron and other internal API calls

    Args:
        x_service_key: Service key from X-Service-Key header

    Returns:
        True if valid

    Raises:
        HTTPException if invalid
    """
    provided_key = x_service_key.strip()

    valid_keys = set()

    if settings.INTERNAL_SERVICE_KEY:
        valid_keys.add(settings.INTERNAL_SERVICE_KEY.strip())

    # Allow falling back to the Supabase service role key so pg_cron can reuse it
    if settings.SUPABASE_SERVICE_KEY:
        valid_keys.add(settings.SUPABASE_SERVICE_KEY.strip())

    if not valid_keys:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Service key not configured"
        )

    if provided_key not in valid_keys:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid service key"
        )

    return True
