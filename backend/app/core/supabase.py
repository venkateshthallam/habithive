from supabase import create_client, Client
from app.core.config import settings
from typing import Optional

def get_supabase_client(access_token: Optional[str] = None) -> Client:
    """Get Supabase client with optional user access token"""
    if settings.TEST_MODE:
        # In test mode, use anon key
        return create_client(
            settings.SUPABASE_URL or "https://test.supabase.co",
            settings.SUPABASE_ANON_KEY or "test-anon-key"
        )
    
    if access_token:
        # Create client with user's access token
        client = create_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)
        client.auth.set_session(access_token, "")
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