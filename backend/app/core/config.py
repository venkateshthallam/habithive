from pydantic_settings import BaseSettings
from typing import Optional
import os

class Settings(BaseSettings):
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_ANON_KEY: str = os.getenv("SUPABASE_ANON_KEY", "")
    SUPABASE_SERVICE_KEY: str = os.getenv("SUPABASE_SERVICE_KEY", "")
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "habithive-test-secret-key-2024")
    TEST_MODE: bool = os.getenv("TEST_MODE", "false").lower() == "true"
    AUTH_TOKEN_MAX_SKEW_SECONDS: int = int(os.getenv("AUTH_TOKEN_MAX_SKEW_SECONDS", "14400"))
    PORT: int = int(os.getenv("PORT", "8002"))

    # OneSignal configuration
    ONESIGNAL_APP_ID: str = os.getenv("ONESIGNAL_APP_ID", "")
    ONESIGNAL_REST_API_KEY: str = os.getenv("ONESIGNAL_REST_API_KEY", "")

    # Service key for internal API calls (pg_cron -> API)
    INTERNAL_SERVICE_KEY: str = os.getenv("INTERNAL_SERVICE_KEY", "")

    class Config:
        env_file = ".env"

settings = Settings()
