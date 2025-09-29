from supabase import create_client, Client
from app.core.config import settings
from typing import Optional, Dict, Any

def get_supabase_client(access_token: Optional[str] = None) -> Client:
    """Get Supabase client with optional user access token"""
    if settings.TEST_MODE:
        # In test mode, use anon key
        return create_client(
            settings.SUPABASE_URL or "https://test.supabase.co",
            settings.SUPABASE_ANON_KEY or "test-anon-key"
        )
    
    if access_token:
        # Create a client scoped to the caller's access token. We avoid set_session
        # because the SDK raises AuthSessionMissingError when no refresh token is
        # provided (our mobile clients only pass the access token). Instead we
        # wire the access token directly into the PostgREST/Storage auth layers
        # so row level security evaluates with the caller's identity.
        client = create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)
        client.postgrest.auth(access_token)

        # Storage and functions also need the user token to respect RLS.
        try:
            client.storage.auth(access_token)
        except AttributeError:
            pass

        try:
            client.functions.set_auth(access_token)
        except AttributeError:
            pass

        return client
    
    # Default client with anon key
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)

def get_supabase_admin() -> Client:
    """Get Supabase admin client with service role key"""
    if settings.TEST_MODE:
        return create_client(
            settings.SUPABASE_URL or "https://test.supabase.co",
            settings.SUPABASE_SERVICE_KEY or "test-service-key"
        )
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)


def get_user_supabase_client(current_user: Dict[str, Any]) -> Client:
    """Create a Supabase client scoped to the authenticated user's access token."""
    access_token = current_user.get("access_token") if current_user else None
    return get_supabase_client(access_token=access_token)
