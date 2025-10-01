from pydantic import BaseModel, Field, field_validator
from typing import Optional, List, Literal, Dict
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

class AppleSignInRequest(BaseModel):
    id_token: str
    nonce: Optional[str] = None

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    user_id: str
    phone: str

# Profile Models
class ProfileBase(BaseModel):
    display_name: str = "New Bee"
    avatar_url: Optional[str] = None
    phone: Optional[str] = None
    timezone: str = "America/New_York"
    day_start_hour: int = Field(4, ge=0, le=23)
    theme: Theme = Theme.honey

class ProfileCreate(ProfileBase):
    pass

class ProfileUpdate(BaseModel):
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    phone: Optional[str] = None
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
    log_date: Optional[date] = None
    client_timestamp: Optional[datetime] = Field(None, alias="client_timestamp")

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
    description: Optional[str] = None
    emoji: Optional[str] = "🍯"
    color_hex: str = "#FFB84C"
    type: HabitType = HabitType.checkbox
    target_per_day: int = Field(1, gt=0)
    rule: Literal["all_must_complete", "threshold"] = "all_must_complete"
    threshold: Optional[int] = None
    schedule_daily: bool = True
    schedule_weekmask: int = Field(127, ge=0, le=127)
    max_members: int = Field(10, ge=2, le=10)

class HiveCreate(HiveBase):
    pass

class HiveUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    emoji: Optional[str] = None
    color_hex: Optional[str] = None
    target_per_day: Optional[int] = Field(None, gt=0)
    rule: Optional[Literal["all_must_complete", "threshold"]] = None
    threshold: Optional[int] = None
    schedule_daily: Optional[bool] = None
    schedule_weekmask: Optional[int] = Field(None, ge=0, le=127)
    max_members: Optional[int] = Field(None, ge=2, le=10)
    is_active: Optional[bool] = None

class HiveFromHabit(BaseModel):
    habit_id: UUID
    name: Optional[str] = None
    backfill_days: int = Field(30, ge=0, le=90)

class Hive(HiveBase):
    id: UUID
    owner_id: UUID
    current_length: Optional[int] = None
    current_streak: Optional[int] = None
    longest_streak: Optional[int] = None
    last_advanced_on: Optional[date] = None
    is_active: bool = True
    invite_code: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    member_count: Optional[int] = None

# Hive Member Models
class HiveMember(BaseModel):
    hive_id: UUID
    user_id: UUID
    role: str = "member"
    joined_at: datetime
    left_at: Optional[datetime] = None
    is_active: bool = True
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None

class HiveMemberDay(BaseModel):
    hive_id: UUID
    user_id: UUID
    day_date: date
    value: int
    done: bool
    created_at: Optional[datetime] = None

class LogHiveRequest(BaseModel):
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

class HiveTodaySummary(BaseModel):
    completed: int = 0
    partial: int = 0
    pending: int = 0
    total: int = 0
    completion_rate: float = 0.0


class HiveMemberStatus(HiveMember):
    status: Literal["completed", "partial", "pending"] = "pending"
    value: int = 0
    target_per_day: int = 1


class HiveLeaderboardEntry(BaseModel):
    user_id: UUID
    display_name: str
    avatar_url: Optional[str] = None
    completed_today: int = 0
    total_hives: int = 0


class HiveOverviewResponse(BaseModel):
    hives: List[Hive]
    leaderboard: List[HiveLeaderboardEntry]


class HiveDetail(Hive):
    avg_completion: float = 0.0
    today_summary: HiveTodaySummary = HiveTodaySummary()
    members: List[HiveMemberStatus] = []
    recent_activity: List[ActivityEvent] = []

class HabitStreakSummary(BaseModel):
    habit_id: UUID
    name: str
    emoji: Optional[str] = None
    streak: int


class HabitPerformance(BaseModel):
    habit_id: UUID
    name: str
    emoji: Optional[str] = None
    completion_rate: float


class HabitPerformanceDetail(BaseModel):
    habit_id: UUID
    name: str
    emoji: Optional[str] = None
    color_hex: str
    type: HabitType
    target_per_day: int
    completion_rate: float
    streak: int


class InsightsRangeStats(BaseModel):
    average_completion: float
    current_streak: int
    habit_performance: List[HabitPerformanceDetail]


class InsightsResponse(BaseModel):
    overall_completion: float
    active_habits: int
    completed_today: int
    weekly_progress: List[int]
    current_streaks: List[HabitStreakSummary]
    year_comb: Dict[str, int]
    best_performing: Optional[HabitPerformance] = None


class InsightsDashboardResponse(BaseModel):
    ranges: Dict[str, InsightsRangeStats]
    year_overview: Dict[str, int]


class HabitHeatmapSeries(BaseModel):
    habit_id: UUID
    name: str
    emoji: Optional[str] = None
    color_hex: str
    counts: Dict[str, int]


class YearOverviewResponse(BaseModel):
    start_date: date
    end_date: date
    totals: Dict[str, int]
    max_total: int = 0
    habits: List[HabitHeatmapSeries] = []
