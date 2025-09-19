from pydantic import BaseModel, Field, field_validator
from typing import Optional, List, Literal
from datetime import datetime, date, time
from uuid import UUID
from enum import Enum

class HabitType(str, Enum):
    checkbox = "checkbox"
    counter = "counter"

class ActivityType(str, Enum):
    habit_completed = "habit_completed"
    streak_milestone = "streak_milestone"
    hive_joined = "hive_joined"
    hive_advanced = "hive_advanced"
    hive_broken = "hive_broken"

class Theme(str, Enum):
    honey = "honey"
    mint = "mint"
    night = "night"

# Auth Models
class PhoneAuthRequest(BaseModel):
    phone: str = Field(..., pattern=r"^\+[1-9]\d{1,14}$")

class VerifyOTPRequest(BaseModel):
    phone: str
    otp: str

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    user_id: str
    phone: str

# Profile Models
class ProfileBase(BaseModel):
    display_name: str = "New Bee"
    avatar_url: Optional[str] = None
    timezone: str = "America/New_York"
    day_start_hour: int = Field(4, ge=0, le=23)
    theme: Theme = Theme.honey

class ProfileCreate(ProfileBase):
    pass

class ProfileUpdate(BaseModel):
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    timezone: Optional[str] = None
    day_start_hour: Optional[int] = Field(None, ge=0, le=23)
    theme: Optional[Theme] = None

class Profile(ProfileBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

# Habit Models
class HabitBase(BaseModel):
    name: str
    emoji: Optional[str] = "🐝"
    color_hex: str = "#FF9F1C"
    type: HabitType = HabitType.checkbox
    target_per_day: int = Field(1, gt=0)
    schedule_daily: bool = True
    schedule_weekmask: int = Field(127, ge=0, le=127)  # Mon-Sun bitmask
    
    @field_validator('color_hex')
    @classmethod
    def validate_color(cls, v):
        if not v.startswith('#'):
            v = f"#{v}"
        if len(v) != 7:
            raise ValueError('Color must be in hex format')
        return v

class HabitCreate(HabitBase):
    pass

class HabitUpdate(BaseModel):
    name: Optional[str] = None
    emoji: Optional[str] = None
    color_hex: Optional[str] = None
    type: Optional[HabitType] = None
    target_per_day: Optional[int] = Field(None, gt=0)
    schedule_daily: Optional[bool] = None
    schedule_weekmask: Optional[int] = Field(None, ge=0, le=127)
    is_active: Optional[bool] = None

class Habit(HabitBase):
    id: UUID
    user_id: UUID
    is_active: bool = True
    created_at: datetime
    updated_at: datetime
    
    model_config = {"json_encoders": {datetime: lambda v: v.isoformat()}}

# Habit Log Models
class HabitLogBase(BaseModel):
    habit_id: UUID
    log_date: date
    value: int = Field(1, gt=0)

class HabitLogCreate(BaseModel):
    value: int = Field(1, gt=0)

class HabitLog(HabitLogBase):
    id: UUID
    user_id: UUID
    source: str = "manual"
    created_at: datetime

class LogHabitRequest(BaseModel):
    habit_id: UUID
    value: int = Field(1, gt=0)
    at: Optional[datetime] = None

# Hive Models
class HiveBase(BaseModel):
    name: str
    color_hex: str = "#FF9F1C"
    type: HabitType = HabitType.checkbox
    target_per_day: int = Field(1, gt=0)
    rule: str = "all_must_complete"
    threshold: Optional[int] = None
    schedule_daily: bool = True
    schedule_weekmask: int = Field(127, ge=0, le=127)

class HiveCreate(HiveBase):
    pass

class HiveFromHabit(BaseModel):
    habit_id: UUID
    name: Optional[str] = None
    backfill_days: int = Field(30, ge=0, le=90)

class Hive(HiveBase):
    id: UUID
    owner_id: UUID
    current_length: int = 0
    last_advanced_on: Optional[date] = None
    created_at: datetime
    member_count: Optional[int] = None

# Hive Member Models
class HiveMember(BaseModel):
    hive_id: UUID
    user_id: UUID
    role: str = "member"
    joined_at: datetime
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None

class HiveMemberDay(BaseModel):
    hive_id: UUID
    user_id: UUID
    day_date: date
    value: int
    done: bool

class LogHiveRequest(BaseModel):
    hive_id: UUID
    value: int = Field(1, gt=0)
    at: Optional[datetime] = None

# Invite Models
class HiveInviteCreate(BaseModel):
    ttl_minutes: int = Field(10080, gt=0)  # 7 days default
    max_uses: int = Field(20, gt=0)

class HiveInvite(BaseModel):
    id: UUID
    hive_id: UUID
    code: str
    created_by: UUID
    expires_at: datetime
    max_uses: int
    use_count: int
    created_at: datetime

class JoinHiveRequest(BaseModel):
    code: str

# Activity Models
class ActivityEvent(BaseModel):
    id: UUID
    actor_id: UUID
    hive_id: Optional[UUID] = None
    habit_id: Optional[UUID] = None
    type: ActivityType
    data: dict = {}
    created_at: datetime
    actor_name: Optional[str] = None
    actor_avatar: Optional[str] = None

# Response Models
class HabitWithLogs(Habit):
    recent_logs: List[HabitLog] = []
    current_streak: int = 0
    completion_rate: float = 0.0

class HiveDetail(Hive):
    members: List[HiveMember] = []
    today_status: dict = {}
    recent_activity: List[ActivityEvent] = []

class InsightsResponse(BaseModel):
    overall_completion: float
    active_habits: int
    current_streaks: dict
    year_comb: dict