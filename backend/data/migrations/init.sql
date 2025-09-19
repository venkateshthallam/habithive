-- ========= Habithive Database Schema =========
-- Supabase PostgreSQL schema for the Habithive habit tracking app
-- Version: 1.0.0

-- ========= Extensions =========
create extension if not exists pgcrypto;

-- ========= Enums =========
do $$
begin
  if not exists (select 1 from pg_type where typname = 'habit_type') then
    create type public.habit_type as enum ('checkbox','counter');
  end if;
  
  if not exists (select 1 from pg_type where typname = 'activity_type') then
    create type public.activity_type as enum (
      'habit_completed','streak_milestone','hive_joined','hive_advanced',
      'hive_broken','friend_added','achievement_earned','habit_created'
    );
  end if;
  
  if not exists (select 1 from pg_type where typname = 'achievement_type') then
    create type public.achievement_type as enum (
      'first_habit','week_streak','month_streak','perfect_week',
      'early_bird','night_owl','social_bee','queen_bee','busy_bee'
    );
  end if;
end $$;

-- ========= Profiles =========
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'New Bee',
  avatar_url text,
  timezone text not null default 'America/New_York',
  day_start_hour int not null default 4 check (day_start_hour between 0 and 23),
  theme text not null default 'honey',
  onboarding_completed boolean not null default false,
  notification_habits boolean not null default true,
  notification_social boolean not null default true,
  notification_time time not null default '09:00:00',
  stats_total_habits int not null default 0,
  stats_total_completions int not null default 0,
  stats_perfect_days int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_created on public.profiles(created_at);

alter table public.profiles enable row level security;

-- Profile trigger for new users
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id, 
    coalesce(
      new.raw_user_meta_data->>'display_name', 
      'Bee ' || substring(new.id::text, 1, 6)
    )
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ========= Device Tokens (APNs) =========
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  apns_token text not null,
  environment text not null default 'prod' check (environment in ('dev', 'prod')),
  device_model text,
  app_version text,
  last_used_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(apns_token)
);

create index if not exists idx_device_tokens_user on public.device_tokens(user_id);
create index if not exists idx_device_tokens_last_used on public.device_tokens(last_used_at);

alter table public.device_tokens enable row level security;

-- ========= Habits =========
create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  emoji text,
  color_hex text not null default '#FFB84C',
  type public.habit_type not null default 'checkbox',
  target_per_day int not null default 1 check (target_per_day > 0),
  schedule_daily boolean not null default true,
  schedule_weekmask int not null default 127, -- bitmask Mon=1..Sun=64
  reminder_enabled boolean not null default false,
  reminder_time time,
  is_active boolean not null default true,
  is_archived boolean not null default false,
  sort_order int not null default 0,
  current_streak int not null default 0,
  longest_streak int not null default 0,
  total_completions int not null default 0,
  last_completed_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_habits_user_active on public.habits(user_id, is_active);
create index if not exists idx_habits_user_archived on public.habits(user_id, is_archived);
create index if not exists idx_habits_sort on public.habits(user_id, sort_order);

alter table public.habits enable row level security;

-- ========= Habit Logs =========
create table if not exists public.habit_logs (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null,
  value int not null default 1 check (value >= 0),
  notes text,
  source text not null default 'manual' check (source in ('manual', 'api', 'widget', 'watch')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (habit_id, log_date)
);

create index if not exists idx_logs_user_date on public.habit_logs(user_id, log_date desc);
create index if not exists idx_logs_habit_date on public.habit_logs(habit_id, log_date desc);
create index if not exists idx_logs_date on public.habit_logs(log_date desc);

alter table public.habit_logs enable row level security;

-- ========= Friendships (Social) =========
create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'blocked')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  unique(user_id, friend_id),
  check (user_id != friend_id)
);

create index if not exists idx_friendships_user on public.friendships(user_id, status);
create index if not exists idx_friendships_friend on public.friendships(friend_id, status);

alter table public.friendships enable row level security;

-- ========= Hives (Groups) =========
create table if not exists public.hives (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  owner_id uuid not null references auth.users(id) on delete cascade,
  emoji text default '🍯',
  color_hex text not null default '#FFB84C',
  type public.habit_type not null default 'checkbox',
  target_per_day int not null default 1,
  rule text not null default 'all_must_complete' check (rule in ('all_must_complete', 'threshold')),
  threshold int,
  schedule_daily boolean not null default true,
  schedule_weekmask int not null default 127,
  current_streak int not null default 0,
  longest_streak int not null default 0,
  last_advanced_on date,
  is_active boolean not null default true,
  max_members int not null default 10 check (max_members between 2 and 10),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_hives_owner on public.hives(owner_id);
create index if not exists idx_hives_active on public.hives(is_active);

alter table public.hives enable row level security;

-- ========= Hive Members =========
create table if not exists public.hive_members (
  hive_id uuid not null references public.hives(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  is_active boolean not null default true,
  primary key (hive_id, user_id)
);

create index if not exists idx_hive_members_user on public.hive_members(user_id, is_active);
create index if not exists idx_hive_members_hive on public.hive_members(hive_id, is_active);

alter table public.hive_members enable row level security;

-- ========= Hive Member Days =========
create table if not exists public.hive_member_days (
  hive_id uuid not null references public.hives(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  day_date date not null,
  value int not null default 1,
  done boolean generated always as (value > 0) stored,
  created_at timestamptz not null default now(),
  primary key (hive_id, user_id, day_date)
);

create index if not exists idx_hive_member_days_date on public.hive_member_days(day_date desc);
create index if not exists idx_hive_member_days_user on public.hive_member_days(user_id, day_date desc);

alter table public.hive_member_days enable row level security;

-- ========= Hive Days (Aggregate) =========
create table if not exists public.hive_days (
  hive_id uuid not null references public.hives(id) on delete cascade,
  day_date date not null,
  complete_count int not null default 0,
  required_count int not null,
  advanced boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (hive_id, day_date)
);

create index if not exists idx_hive_days_date on public.hive_days(day_date desc);

alter table public.hive_days enable row level security;

-- ========= Hive Invites =========
create table if not exists public.hive_invites (
  id uuid primary key default gen_random_uuid(),
  hive_id uuid not null references public.hives(id) on delete cascade,
  code text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  max_uses int not null default 20,
  use_count int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_invites_code on public.hive_invites(code);
create index if not exists idx_invites_expires on public.hive_invites(expires_at);

alter table public.hive_invites enable row level security;

-- ========= Achievements =========
create table if not exists public.achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type public.achievement_type not null,
  earned_at timestamptz not null default now(),
  data jsonb not null default '{}'::jsonb,
  unique(user_id, type)
);

create index if not exists idx_achievements_user on public.achievements(user_id);
create index if not exists idx_achievements_earned on public.achievements(earned_at desc);

alter table public.achievements enable row level security;

-- ========= Activity Feed =========
create table if not exists public.activity_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id) on delete cascade,
  hive_id uuid references public.hives(id) on delete cascade,
  habit_id uuid references public.habits(id) on delete cascade,
  type public.activity_type not null,
  data jsonb not null default '{}'::jsonb,
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_activity_actor on public.activity_events(actor_id, created_at desc);
create index if not exists idx_activity_hive on public.activity_events(hive_id, created_at desc);
create index if not exists idx_activity_public on public.activity_events(is_public, created_at desc) where is_public = true;

alter table public.activity_events enable row level security;

-- ========= RLS Policies =========
-- Now we can safely create policies after tables exist

-- Profiles policies
do $$ begin
  drop policy if exists "read own profile" on public.profiles;
  drop policy if exists "update own profile" on public.profiles;
  drop policy if exists "read friends profiles" on public.profiles;
exception when others then null;
end $$;

create policy "read own profile" on public.profiles
  for select using (auth.uid() = id);
  
create policy "update own profile" on public.profiles
  for update using (auth.uid() = id);

create policy "read friends profiles" on public.profiles
  for select using (
    exists (
      select 1 from public.friendships
      where status = 'accepted'
        and ((user_id = auth.uid() and friend_id = profiles.id)
          or (friend_id = auth.uid() and user_id = profiles.id))
    )
  );

-- Device Tokens policies
do $$ begin
  drop policy if exists "owner manage tokens" on public.device_tokens;
exception when others then null;
end $$;

create policy "owner manage tokens" on public.device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Habits policies
do $$ begin
  drop policy if exists "owner crud habit" on public.habits;
exception when others then null;
end $$;

create policy "owner crud habit" on public.habits
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Habit Logs policies
do $$ begin
  drop policy if exists "owner manage logs" on public.habit_logs;
  drop policy if exists "owner read logs" on public.habit_logs;
  drop policy if exists "owner write logs" on public.habit_logs;
  drop policy if exists "owner update logs" on public.habit_logs;
  drop policy if exists "owner delete logs" on public.habit_logs;
exception when others then null;
end $$;

create policy "owner manage logs" on public.habit_logs
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Friendships policies
do $$ begin
  drop policy if exists "manage own friendships" on public.friendships;
exception when others then null;
end $$;

create policy "manage own friendships" on public.friendships
  for all using (user_id = auth.uid() or friend_id = auth.uid())
  with check (user_id = auth.uid() or friend_id = auth.uid());

-- Hives policies
do $$ begin
  drop policy if exists "members read hives" on public.hives;
  drop policy if exists "owner manage hive" on public.hives;
exception when others then null;
end $$;

create policy "members read hives" on public.hives
  for select using (
    exists (
      select 1 from public.hive_members m
      where m.hive_id = hives.id and m.user_id = auth.uid() and m.is_active = true
    )
  );

create policy "owner manage hive" on public.hives
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Hive Members policies
do $$ begin
  drop policy if exists "members read list" on public.hive_members;
  drop policy if exists "owner manage members" on public.hive_members;
  drop policy if exists "owner add members" on public.hive_members;
  drop policy if exists "owner remove members" on public.hive_members;
exception when others then null;
end $$;

create policy "members read list" on public.hive_members
  for select using (
    exists (
      select 1 from public.hive_members m
      where m.hive_id = hive_members.hive_id and m.user_id = auth.uid() and m.is_active = true
    )
  );

create policy "owner manage members" on public.hive_members
  for all using (
    exists (
      select 1 from public.hives h
      where h.id = hive_members.hive_id and h.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.hives h
      where h.id = hive_members.hive_id and h.owner_id = auth.uid()
    )
  );

-- Hive Member Days policies
do $$ begin
  drop policy if exists "member manage own days" on public.hive_member_days;
  drop policy if exists "members read all days" on public.hive_member_days;
  drop policy if exists "member write own day" on public.hive_member_days;
  drop policy if exists "members read days" on public.hive_member_days;
exception when others then null;
end $$;

create policy "member manage own days" on public.hive_member_days
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "members read all days" on public.hive_member_days
  for select using (
    exists (
      select 1 from public.hive_members m
      where m.hive_id = hive_member_days.hive_id and m.user_id = auth.uid() and m.is_active = true
    )
  );

-- Hive Days policies
do $$ begin
  drop policy if exists "members read hive days" on public.hive_days;
exception when others then null;
end $$;

create policy "members read hive days" on public.hive_days
  for select using (
    exists (
      select 1 from public.hive_members m
      where m.hive_id = hive_days.hive_id and m.user_id = auth.uid() and m.is_active = true
    )
  );

-- Hive Invites policies
do $$ begin
  drop policy if exists "members read invites" on public.hive_invites;
  drop policy if exists "owner create invites" on public.hive_invites;
exception when others then null;
end $$;

create policy "members read invites" on public.hive_invites
  for select using (
    exists (
      select 1 from public.hive_members m
      where m.hive_id = hive_invites.hive_id and m.user_id = auth.uid() and m.is_active = true
    )
  );

create policy "owner create invites" on public.hive_invites
  for insert with check (
    exists (
      select 1 from public.hives h
      where h.id = hive_invites.hive_id and h.owner_id = auth.uid()
    )
  );

-- Achievements policies
do $$ begin
  drop policy if exists "read own achievements" on public.achievements;
  drop policy if exists "read friends achievements" on public.achievements;
exception when others then null;
end $$;

create policy "read own achievements" on public.achievements
  for select using (user_id = auth.uid());

create policy "read friends achievements" on public.achievements
  for select using (
    exists (
      select 1 from public.friendships
      where status = 'accepted'
        and ((user_id = auth.uid() and friend_id = achievements.user_id)
          or (friend_id = auth.uid() and user_id = achievements.user_id))
    )
  );

-- Activity Events policies
do $$ begin
  drop policy if exists "read own activity" on public.activity_events;
  drop policy if exists "read hive activity" on public.activity_events;
  drop policy if exists "read friends activity" on public.activity_events;
  drop policy if exists "actor writes events" on public.activity_events;
  drop policy if exists "members read hive activity" on public.activity_events;
exception when others then null;
end $$;

create policy "read own activity" on public.activity_events
  for select using (actor_id = auth.uid());

create policy "read hive activity" on public.activity_events
  for select using (
    hive_id is not null and exists (
      select 1 from public.hive_members m
      where m.hive_id = activity_events.hive_id and m.user_id = auth.uid() and m.is_active = true
    )
  );

create policy "read friends activity" on public.activity_events
  for select using (
    is_public = true and exists (
      select 1 from public.friendships
      where status = 'accepted'
        and ((user_id = auth.uid() and friend_id = activity_events.actor_id)
          or (friend_id = auth.uid() and user_id = activity_events.actor_id))
    )
  );

create policy "actor writes events" on public.activity_events
  for insert with check (actor_id = auth.uid());

-- ========= Helper Functions =========

-- Get user's local date
create or replace function public.user_local_date(
  p_user uuid,
  p_at timestamptz default now()
)
returns date
language sql stable
as $$
  select (
    (p_at at time zone coalesce(
      (select timezone from public.profiles where id = p_user),
      'UTC'
    ) - make_interval(hours => coalesce(
      (select day_start_hour from public.profiles where id = p_user),
      4
    )))::date
  );
$$;

-- Calculate streak for a habit
create or replace function public.calculate_habit_streak(p_habit_id uuid)
returns table(current_streak int, longest_streak int)
language plpgsql stable
as $$
declare
  v_current int := 0;
  v_longest int := 0;
  v_temp int := 0;
  v_last_date date := null;
  r record;
begin
  for r in (
    select log_date
    from public.habit_logs
    where habit_id = p_habit_id
    order by log_date desc
  ) loop
    if v_last_date is null or r.log_date = v_last_date - interval '1 day' then
      v_temp := v_temp + 1;
      if v_current = 0 then
        v_current := v_temp;
      end if;
    else
      v_longest := greatest(v_longest, v_temp);
      v_temp := 1;
    end if;
    v_last_date := r.log_date;
  end loop;
  
  v_longest := greatest(v_longest, v_temp, v_current);
  
  return query select v_current, v_longest;
end $$;

-- Log a habit and update streaks
create or replace function public.log_habit(
  p_habit_id uuid,
  p_value int default 1,
  p_notes text default null,
  p_at timestamptz default now()
)
returns public.habit_logs
language plpgsql security definer
as $$
declare
  v_user uuid;
  v_date date;
  v_target int;
  v_last_date date;
  rec public.habit_logs;
  v_current_streak int;
  v_longest_streak int;
begin
  -- Get habit details
  select user_id, target_per_day, last_completed_date
  into v_user, v_target, v_last_date
  from public.habits
  where id = p_habit_id;
  
  if v_user is null then
    raise exception 'Habit not found';
  end if;
  
  if v_user != auth.uid() then
    raise exception 'Not authorized';
  end if;
  
  -- Calculate user's local date
  v_date := public.user_local_date(v_user, p_at);
  
  -- Cap value at target
  p_value := least(greatest(p_value, 0), v_target);
  
  -- Insert or update log
  insert into public.habit_logs(habit_id, user_id, log_date, value, notes, source)
  values (p_habit_id, v_user, v_date, p_value, p_notes, 'api')
  on conflict (habit_id, log_date)
  do update set 
    value = excluded.value,
    notes = excluded.notes,
    updated_at = now()
  returning * into rec;
  
  -- Calculate and update streaks
  select current_streak, longest_streak
  into v_current_streak, v_longest_streak
  from public.calculate_habit_streak(p_habit_id);
  
  -- Update habit stats
  update public.habits
  set 
    current_streak = v_current_streak,
    longest_streak = v_longest_streak,
    last_completed_date = v_date,
    total_completions = (
      select count(*) from public.habit_logs
      where habit_id = p_habit_id and value > 0
    ),
    updated_at = now()
  where id = p_habit_id;
  
  -- Update profile stats
  update public.profiles
  set 
    stats_total_completions = stats_total_completions + 1,
    updated_at = now()
  where id = v_user;
  
  -- Create activity event
  if p_value > 0 then
    insert into public.activity_events(actor_id, habit_id, type, data, is_public)
    values (
      v_user,
      p_habit_id,
      'habit_completed',
      jsonb_build_object(
        'log_date', v_date,
        'value', p_value,
        'streak', v_current_streak
      ),
      true
    );
    
    -- Check for streak milestones
    if v_current_streak in (7, 30, 100, 365) then
      insert into public.activity_events(actor_id, habit_id, type, data, is_public)
      values (
        v_user,
        p_habit_id,
        'streak_milestone',
        jsonb_build_object(
          'milestone', v_current_streak,
          'habit_name', (select name from public.habits where id = p_habit_id)
        ),
        true
      );
      
      -- Award achievement
      if v_current_streak = 7 then
        insert into public.achievements(user_id, type, data)
        values (v_user, 'week_streak', jsonb_build_object('habit_id', p_habit_id))
        on conflict do nothing;
      elsif v_current_streak = 30 then
        insert into public.achievements(user_id, type, data)
        values (v_user, 'month_streak', jsonb_build_object('habit_id', p_habit_id))
        on conflict do nothing;
      end if;
    end if;
  end if;
  
  return rec;
end $$;

-- Get today's habits with completion status
create or replace function public.get_todays_habits(p_date date default null)
returns table(
  habit_id uuid,
  name text,
  emoji text,
  color_hex text,
  type habit_type,
  target_per_day int,
  current_streak int,
  completed_today boolean,
  value_today int
)
language plpgsql stable
as $$
declare
  v_date date;
  v_weekday int;
begin
  v_date := coalesce(p_date, public.user_local_date(auth.uid()));
  v_weekday := extract(dow from v_date);
  -- Convert Sunday (0) to 7 for our bitmask
  if v_weekday = 0 then v_weekday := 7; end if;
  
  return query
  select 
    h.id,
    h.name,
    h.emoji,
    h.color_hex,
    h.type,
    h.target_per_day,
    h.current_streak,
    coalesce(l.value, 0) > 0 as completed_today,
    coalesce(l.value, 0) as value_today
  from public.habits h
  left join public.habit_logs l on (
    l.habit_id = h.id and l.log_date = v_date
  )
  where h.user_id = auth.uid()
    and h.is_active = true
    and h.is_archived = false
    and (
      h.schedule_daily = true
      or (h.schedule_weekmask & (1 << (v_weekday - 1))) > 0
    )
  order by h.sort_order, h.created_at;
end $$;

-- Create hive from habit
create or replace function public.create_hive_from_habit(
  p_habit_id uuid,
  p_name text default null,
  p_description text default null,
  p_backfill_days int default 30
)
returns uuid
language plpgsql security definer
as $$
declare
  v_hive uuid;
  v_habit record;
begin
  -- Get habit details
  select * into v_habit
  from public.habits
  where id = p_habit_id and user_id = auth.uid();
  
  if v_habit is null then
    raise exception 'Habit not found or not authorized';
  end if;
  
  -- Create hive
  insert into public.hives(
    name, description, owner_id, emoji, color_hex,
    type, target_per_day, schedule_daily, schedule_weekmask
  )
  values (
    coalesce(p_name, v_habit.name || ' Hive'),
    p_description,
    auth.uid(),
    v_habit.emoji,
    v_habit.color_hex,
    v_habit.type,
    v_habit.target_per_day,
    v_habit.schedule_daily,
    v_habit.schedule_weekmask
  )
  returning id into v_hive;
  
  -- Add owner as member
  insert into public.hive_members(hive_id, user_id, role)
  values (v_hive, auth.uid(), 'owner');
  
  -- Backfill recent logs if requested
  if p_backfill_days > 0 then
    insert into public.hive_member_days(hive_id, user_id, day_date, value)
    select v_hive, auth.uid(), log_date, value
    from public.habit_logs
    where habit_id = p_habit_id
      and log_date >= (current_date - p_backfill_days)
    on conflict do nothing;
  end if;
  
  return v_hive;
end $$;

-- Join hive with invite code
create or replace function public.join_hive_with_code(p_code text)
returns uuid
language plpgsql security definer
as $$
declare
  v_invite record;
  v_member_count int;
begin
  -- Get invite details
  select * into v_invite
  from public.hive_invites
  where code = p_code;
  
  if v_invite is null then
    raise exception 'Invalid invite code';
  end if;
  
  if v_invite.expires_at < now() then
    raise exception 'Invite has expired';
  end if;
  
  if v_invite.use_count >= v_invite.max_uses then
    raise exception 'Invite has been used maximum times';
  end if;
  
  -- Check hive member count
  select count(*) into v_member_count
  from public.hive_members
  where hive_id = v_invite.hive_id and is_active = true;
  
  if v_member_count >= 10 then
    raise exception 'Hive is full (max 10 members)';
  end if;
  
  -- Add member
  insert into public.hive_members(hive_id, user_id, role)
  values (v_invite.hive_id, auth.uid(), 'member')
  on conflict (hive_id, user_id) do update
  set is_active = true, left_at = null;
  
  -- Update invite use count
  update public.hive_invites
  set use_count = use_count + 1
  where id = v_invite.id;
  
  -- Create activity event
  insert into public.activity_events(actor_id, hive_id, type, data)
  values (
    auth.uid(),
    v_invite.hive_id,
    'hive_joined',
    jsonb_build_object('invite_code', p_code)
  );
  
  return v_invite.hive_id;
end $$;

-- Create invite for hive
create or replace function public.create_hive_invite(
  p_hive_id uuid,
  p_ttl_minutes int default 10080,  -- 7 days
  p_max_uses int default 20
)
returns public.hive_invites
language plpgsql security definer
as $$
declare
  v_code text;
  rec public.hive_invites;
begin
  -- Verify ownership
  if not exists (
    select 1 from public.hives
    where id = p_hive_id and owner_id = auth.uid()
  ) then
    raise exception 'Only hive owner can create invites';
  end if;
  
  -- Generate unique code
  v_code := upper(encode(gen_random_bytes(3), 'hex'));
  
  -- Create invite
  insert into public.hive_invites(
    hive_id, code, created_by, expires_at, max_uses
  )
  values (
    p_hive_id,
    v_code,
    auth.uid(),
    now() + make_interval(mins => p_ttl_minutes),
    p_max_uses
  )
  returning * into rec;
  
  return rec;
end $$;

-- Grant permissions
grant usage on schema public to anon, authenticated;
grant all on all tables in schema public to authenticated;
grant all on all sequences in schema public to authenticated;
grant execute on all functions in schema public to authenticated;

-- ========= Views for easier querying =========

-- Today's summary view
create or replace view public.today_summary as
select 
  p.id as user_id,
  p.display_name,
  count(distinct h.id) as total_habits,
  count(distinct case when l.value > 0 then h.id end) as completed_habits,
  round(100.0 * count(distinct case when l.value > 0 then h.id end) / 
    nullif(count(distinct h.id), 0), 1) as completion_percentage,
  max(h.current_streak) as best_streak
from public.profiles p
left join public.habits h on h.user_id = p.id and h.is_active = true
left join public.habit_logs l on l.habit_id = h.id 
  and l.log_date = public.user_local_date(p.id)
where p.id = auth.uid()
group by p.id, p.display_name;

grant select on public.today_summary to authenticated;

-- Weekly stats view
create or replace view public.weekly_stats as
select 
  h.id as habit_id,
  h.name,
  h.emoji,
  h.current_streak,
  count(case when l.value > 0 then 1 end) as days_completed,
  round(100.0 * count(case when l.value > 0 then 1 end) / 7, 1) as week_percentage
from public.habits h
left join public.habit_logs l on l.habit_id = h.id 
  and l.log_date >= public.user_local_date(h.user_id) - interval '6 days'
  and l.log_date <= public.user_local_date(h.user_id)
where h.user_id = auth.uid() and h.is_active = true
group by h.id, h.name, h.emoji, h.current_streak
order by week_percentage desc, h.current_streak desc;

grant select on public.weekly_stats to authenticated;