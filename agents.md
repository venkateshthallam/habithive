0) Quick runbook (for your AI agent)

Design System:

🎨 Color System
Primary: Honey gradient (#FFD074 → #FFA629)
Success: Leaf Green (#4BBF8B)
Text: Gray scale (#171717 → #FAFAFA)
Accent: Coral Pink (#FFB4B4)
📝 Typography
Primary Font: SF Pro Display / Inter
Headers: 24-36px, Font-weight: 700-900
Body: 14-16px, Font-weight: 400-500
Captions: 11-12px, Font-weight: 500-600
✨ Interactions
• Bee Button: Press & hold to complete (haptic feedback)
• Honeycomb cells: Tap to mark, swipe to navigate dates
• Animations: Cubic-bezier(0.4, 0, 0.2, 1) for smooth feel
• Shadows: Multi-layered for depth (xs → xl)

1) PRD — HabitHive (MVP)

Core promise: “One‑tap logging with a delightful Honey Pour animation and a social Hive where 2–10 friends keep a combined streak.”

In‑scope (MVP)

Auth: Phone OTP; optional Apple; auto‑link phone later.

Onboarding (5 steps): (1) Theme, (2) Starter habits, (3) Day start/timezone, (4) Find friends (contacts hash), (5) Auth + notifications + micro‑tutorial.

Habits: Create, edit (emoji, color, schedule, type=checkbox/counter, target), reminders (stored; client schedules local), archive.

Logging: Tap or press‑&‑hold “Honey Pour” to log today; edit past days from month view.

Insights: Overall completion, current streaks, Year Comb heatmap per habit.

Hive (Groups): Create hive from scratch or convert habit → hive; invite by code or contact match; all‑must‑complete rule to advance shared streak; size 2–10.

Activity: Lightweight friend feed scoped to your hives (join/complete/milestones).

Notifications: Local habit reminders; push for “Hive at risk” and milestones.

Out of scope (MVP)

Public feed/discovery, chat, web app, Android, paywalls (show “Premium” but do not block).

Success metrics

Activation: % completing ≥1 log D1.

Social: % of active users in ≥1 hive; invites/user.

Retention: D7/D30.

Engagement: avg logs/user/day; reminder opt‑in.

Mechanics (important rules)

User‑local day = date computed by timezone + day_start_hour.

Habit log uniqueness: (habit_id, log_date) unique.

Counter cap: value ≤ target_per_day.

Hive advance: for date D, advance if every member has done=true for D. Shared streak resets if not advanced by day close.

Convert habit→hive: copy the habit’s metadata; owner becomes first member; (optional) backfill last 30–90 days into hive_member_days.

2) Supabase DDL (tables, RLS, RPCs, seeds)

Paste the whole block (in order) into Supabase SQL editor.
Uses gen_random_uuid(); Supabase has pgcrypto enabled.

-- ========= Extensions =========
create extension if not exists pgcrypto;

-- ========= Profiles =========
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'New Bee',
  avatar_url text,
  timezone text not null default 'America/New_York',
  day_start_hour int not null default 4 check (day_start_hour between 0 and 23),
  theme text not null default 'honey',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', 'Bee ' || substring(new.id::text,1,6)))
  on conflict (id) do nothing;
  return new;
end $$;

-- Bind (or keep your existing trigger name if already present)
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- RLS for profiles
create policy if not exists "read own profile" on public.profiles
for select using (auth.uid() = id);
create policy if not exists "insert own profile" on public.profiles
for insert with check (auth.uid() = id);
create policy if not exists "update own profile" on public.profiles
for update using (auth.uid() = id);

-- ========= Device tokens (APNs) =========
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  apns_token text not null,
  environment text not null default 'prod',
  created_at timestamptz not null default now(),
  unique(apns_token)
);
alter table public.device_tokens enable row level security;
create policy if not exists "owner manage tokens" on public.device_tokens
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ========= Habits & Logs =========
do $$
begin
  if not exists (select 1 from pg_type where typname = 'habit_type') then
    create type public.habit_type as enum ('checkbox','counter');
  end if;
end $$;

create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  emoji text,
  color_hex text not null default '#FF9F1C',
  type public.habit_type not null default 'checkbox',
  target_per_day int not null default 1 check (target_per_day > 0),
  schedule_daily boolean not null default true,
  schedule_weekmask int not null default 127, -- bitmask Mon..Sun
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_habits_user on public.habits(user_id);

alter table public.habits enable row level security;
create policy if not exists "owner crud habit" on public.habits
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.habit_logs (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null,                -- user-local day
  value int not null default 1,
  source text not null default 'manual',
  created_at timestamptz not null default now(),
  unique (habit_id, log_date)
);
create index if not exists idx_logs_user_date on public.habit_logs(user_id, log_date);

alter table public.habit_logs enable row level security;
create policy if not exists "owner read logs" on public.habit_logs
for select using (user_id = auth.uid());
create policy if not exists "owner write logs" on public.habit_logs
for insert with check (user_id = auth.uid());
create policy if not exists "owner delete logs" on public.habit_logs
for delete using (user_id = auth.uid());

-- ========= Hives (groups 2–10) =========
create table if not exists public.hives (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  color_hex text not null default '#FF9F1C',
  type public.habit_type not null default 'checkbox',
  target_per_day int not null default 1,
  rule text not null default 'all_must_complete',  -- future: 'threshold'
  threshold int,
  schedule_daily boolean not null default true,
  schedule_weekmask int not null default 127,
  current_length int not null default 0,
  last_advanced_on date,
  created_at timestamptz not null default now()
);
create index if not exists idx_hives_owner on public.hives(owner_id);

create table if not exists public.hive_members (
  hive_id uuid not null references public.hives(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (hive_id, user_id)
);
create index if not exists idx_hive_members_user on public.hive_members(user_id);

create table if not exists public.hive_member_days (
  hive_id uuid not null references public.hives(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  day_date date not null,
  value int not null default 1,
  done boolean generated always as (value > 0) stored,
  primary key (hive_id, user_id, day_date)
);

create table if not exists public.hive_days (
  hive_id uuid not null references public.hives(id) on delete cascade,
  day_date date not null,
  complete_count int not null default 0,
  required_count int not null,
  advanced boolean not null default false,
  primary key (hive_id, day_date)
);

alter table public.hives enable row level security;
create policy if not exists "members read hives" on public.hives
for select using (exists (select 1 from public.hive_members m where m.hive_id = hives.id and m.user_id = auth.uid()));
create policy if not exists "owner manage hive" on public.hives
for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

alter table public.hive_members enable row level security;
create policy if not exists "members read list" on public.hive_members
for select using (exists (select 1 from public.hive_members mm where mm.hive_id = hive_members.hive_id and mm.user_id = auth.uid()));
create policy if not exists "owner add members" on public.hive_members
for insert with check (exists (select 1 from public.hives h where h.id = hive_members.hive_id and h.owner_id = auth.uid()));
create policy if not exists "owner remove members" on public.hive_members
for delete using (exists (select 1 from public.hives h where h.id = hive_members.hive_id and h.owner_id = auth.uid()));

alter table public.hive_member_days enable row level security;
create policy if not exists "member write own day" on public.hive_member_days
for insert with check (user_id = auth.uid());
create policy if not exists "members read days" on public.hive_member_days
for select using (exists (select 1 from public.hive_members m where m.hive_id = hive_member_days.hive_id and m.user_id = auth.uid()));

alter table public.hive_days enable row level security;
create policy if not exists "members read hive days" on public.hive_days
for select using (exists (select 1 from public.hive_members m where m.hive_id = hive_days.hive_id and m.user_id = auth.uid()));

-- ========= Invites & Contacts =========
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
alter table public.hive_invites enable row level security;
create policy if not exists "members read invites" on public.hive_invites
for select using (exists (select 1 from public.hive_members m where m.hive_id = hive_invites.hive_id and m.user_id = auth.uid()));
create policy if not exists "owner create invites" on public.hive_invites
for insert with check (exists (select 1 from public.hives h where h.id = hive_invites.hive_id and h.owner_id = auth.uid()));

-- Phone-hash table for contact matching (store only hashes)
create table if not exists public.contact_hashes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  contact_hash text not null,   -- sha256(pepper || e164)
  display_name text,
  imported_at timestamptz not null default now(),
  unique(user_id, contact_hash)
);
alter table public.contact_hashes enable row level security;
create policy if not exists "owner manage contacts" on public.contact_hashes
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ========= Activity (feed) =========
do $$
begin
  if not exists (select 1 from pg_type where typname = 'activity_type') then
    create type public.activity_type as enum (
      'habit_completed','streak_milestone','hive_joined','hive_advanced','hive_broken'
    );
  end if;
end $$;

create table if not exists public.activity_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id) on delete cascade,
  hive_id uuid references public.hives(id),
  habit_id uuid references public.habits(id),
  type public.activity_type not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_activity_hive_time on public.activity_events(hive_id, created_at desc);

alter table public.activity_events enable row level security;
create policy if not exists "members read hive activity" on public.activity_events
for select using (
  hive_id is null or
  exists (select 1 from public.hive_members m where m.hive_id = activity_events.hive_id and m.user_id = auth.uid())
);
create policy if not exists "actor writes events" on public.activity_events
for insert with check (actor_id = auth.uid());

-- ========= Helper functions (RPC) =========

-- Compute user-local date given timestamp
create or replace function public.user_local_date(p_user uuid, p_at timestamptz default now())
returns date
language sql stable
set search_path = public
as $$
  select (
    ((p_at at time zone coalesce((select timezone from public.profiles where id = p_user),'UTC'))
     - make_interval(hours => coalesce((select day_start_hour from public.profiles where id = p_user),0)))::date
  );
$$;

-- Log habit for "today" (upsert); caps value at target
create or replace function public.log_habit(p_habit_id uuid, p_value int default 1, p_at timestamptz default now())
returns public.habit_logs
language plpgsql security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_date date;
  v_target int;
  rec public.habit_logs;
begin
  select user_id, target_per_day into v_user, v_target from public.habits where id = p_habit_id;
  if v_user is null then raise exception 'habit not found'; end if;
  if v_user <> auth.uid() then raise exception 'not owner'; end if;

  select public.user_local_date(v_user, p_at) into v_date;
  p_value := least(greatest(p_value,1), v_target);

  insert into public.habit_logs(habit_id, user_id, log_date, value, source)
  values (p_habit_id, v_user, v_date, p_value, 'api')
  on conflict (habit_id, log_date)
  do update set value = excluded.value, created_at = now()
  returning * into rec;

  -- Emit activity
  insert into public.activity_events(actor_id, habit_id, type, data)
  values (v_user, p_habit_id, 'habit_completed', jsonb_build_object('log_date', v_date))
  on conflict do nothing;

  return rec;
end $$;

grant execute on function public.user_local_date(uuid, timestamptz) to anon, authenticated;
grant execute on function public.log_habit(uuid, int, timestamptz) to authenticated;

-- Convert an existing habit into a hive and (optionally) backfill recent logs
create or replace function public.create_hive_from_habit(p_habit_id uuid, p_name text default null, p_backfill_days int default 30)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_hive uuid;
  v_owner uuid;
  v_name text;
  v_color text;
  v_type public.habit_type;
  v_target int;
  v_sched_daily boolean;
  v_weekmask int;
begin
  select user_id, name, color_hex, type, target_per_day, schedule_daily, schedule_weekmask
  into v_owner, v_name, v_color, v_type, v_target, v_sched_daily, v_weekmask
  from public.habits where id = p_habit_id and user_id = auth.uid();

  if v_owner is null then raise exception 'habit not found or not owner'; end if;

  insert into public.hives(name, owner_id, color_hex, type, target_per_day, rule, schedule_daily, schedule_weekmask)
  values (coalesce(p_name, v_name), v_owner, v_color, v_type, v_target, 'all_must_complete', v_sched_daily, v_weekmask)
  returning id into v_hive;

  insert into public.hive_members(hive_id, user_id, role) values (v_hive, v_owner, 'owner');

  if p_backfill_days > 0 then
    insert into public.hive_member_days(hive_id, user_id, day_date, value)
    select v_hive, v_owner, log_date, value
    from public.habit_logs
    where habit_id = p_habit_id
      and log_date >= (current_date - p_backfill_days)
    on conflict do nothing;
  end if;

  return v_hive;
end $$;

grant execute on function public.create_hive_from_habit(uuid, text, int) to authenticated;

-- Create a new invite code for a hive (owner only)
create or replace function public.create_hive_invite(p_hive_id uuid, p_ttl_minutes int default 10080, p_max_uses int default 20)
returns public.hive_invites
language plpgsql security definer
set search_path = public
as $$
declare
  v_code text := encode(gen_random_bytes(6),'hex');
  rec public.hive_invites;
begin
  if not exists (select 1 from public.hives where id = p_hive_id and owner_id = auth.uid()) then
    raise exception 'only owner can create invite';
  end if;

  insert into public.hive_invites(hive_id, code, created_by, expires_at, max_uses)
  values (p_hive_id, v_code, auth.uid(), now() + make_interval(mins => p_ttl_minutes), p_max_uses)
  returning * into rec;
  return rec;
end $$;

grant execute on function public.create_hive_invite(uuid, int, int) to authenticated;

-- Join a hive via code
create or replace function public.join_hive_with_code(p_code text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_hive uuid;
  v_uses int;
  v_max int;
  v_exp timestamptz;
  v_member_count int;
begin
  select hive_id, use_count, max_uses, expires_at into v_hive, v_uses, v_max, v_exp
  from public.hive_invites where code = p_code;

  if v_hive is null then raise exception 'invalid code'; end if;
  if v_exp < now() then raise exception 'invite expired'; end if;
  if v_uses >= v_max then raise exception 'invite exhausted'; end if;

  select count(*) into v_member_count from public.hive_members where hive_id = v_hive;
  if v_member_count >= 10 then raise exception 'hive full'; end if;

  insert into public.hive_members(hive_id, user_id) values (v_hive, auth.uid())
  on conflict do nothing;

  update public.hive_invites set use_count = use_count + 1 where code = p_code;

  -- Feed
  insert into public.activity_events(actor_id, hive_id, type)
  values (auth.uid(), v_hive, 'hive_joined');

  return v_hive;
end $$;

grant execute on function public.join_hive_with_code(text) to authenticated;

-- Mark/Upsert a member's day in a hive (today by default)
create or replace function public.log_hive_today(p_hive_id uuid, p_value int default 1, p_at timestamptz default now())
returns public.hive_member_days
language plpgsql security definer
set search_path = public
as $$
declare
  v_date date;
  rec public.hive_member_days;
begin
  select public.user_local_date(auth.uid(), p_at) into v_date;

  insert into public.hive_member_days(hive_id, user_id, day_date, value)
  values (p_hive_id, auth.uid(), v_date, greatest(1, p_value))
  on conflict (hive_id, user_id, day_date)
  do update set value = excluded.value
  returning * into rec;

  return rec;
end $$;

grant execute on function public.log_hive_today(uuid, int, timestamptz) to authenticated;

-- Aggregate a hive for a given day and maybe advance shared streak
create or replace function public.advance_hive_day(p_hive_id uuid, p_day date)
returns table(advanced boolean, complete_count int, required_count int)
language plpgsql security definer
set search_path = public
as $$
declare
  v_required int;
  v_done int;
  v_advanced boolean := false;
  v_last date;
begin
  select count(*) into v_required from public.hive_members where hive_id = p_hive_id;
  select count(*) into v_done from public.hive_member_days where hive_id = p_hive_id and day_date = p_day and done = true;

  insert into public.hive_days(hive_id, day_date, complete_count, required_count, advanced)
  values (p_hive_id, p_day, v_done, v_required, false)
  on conflict (hive_id, day_date)
  do update set complete_count = excluded.complete_count, required_count = excluded.required_count;

  if v_done = v_required then
    update public.hive_days set advanced = true where hive_id = p_hive_id and day_date = p_day;
    select last_advanced_on into v_last from public.hives where id = p_hive_id;

    if v_last is null or v_last < p_day then
      update public.hives
      set current_length = current_length + 1,
          last_advanced_on = p_day
      where id = p_hive_id;
    end if;

    v_advanced := true;

    insert into public.activity_events(actor_id, hive_id, type, data)
    values (auth.uid(), p_hive_id, 'hive_advanced', jsonb_build_object('day', p_day))
    on conflict do nothing;
  end if;

  return query select v_advanced, v_done, v_required;
end $$;

grant execute on function public.advance_hive_day(uuid, date) to authenticated;

-- ========= Dev seed (optional; requires an existing auth user) =========
-- Replace '00000000-0000-0000-0000-000000000000' with a real auth.users.id
-- insert into public.habits(user_id, name, emoji, color_hex) values
-- ('00000000-0000-0000-0000-000000000000','Drink Water','💧','#34C8ED');

3) Endpoints (callable from the iOS app)

Supabase gives you PostgREST for tables and RPC for SQL functions.

3A. Table routes (PostgREST)

GET /rest/v1/profiles?id=eq.<uid>

PATCH /rest/v1/profiles?id=eq.<uid> body: { display_name, timezone, day_start_hour, theme }

GET /rest/v1/habits?select=*&order=created_at.desc

POST /rest/v1/habits body: { name, emoji, color_hex, type, target_per_day, schedule_daily, schedule_weekmask }

PATCH /rest/v1/habits?id=eq.<habit_id>

DELETE /rest/v1/habits?id=eq.<habit_id>

GET /rest/v1/habit_logs?habit_id=eq.<habit_id>&log_date=gte.<YYYY-MM-DD>&log_date=lte.<YYYY-MM-DD>

DELETE /rest/v1/habit_logs?habit_id=eq.<habit_id>&log_date=eq.<YYYY-MM-DD>

GET /rest/v1/hives?select=*,hive_members(count)

GET /rest/v1/hive_members?hive_id=eq.<hive_id>&select=user_id,role,joined_at

GET /rest/v1/hive_member_days?hive_id=eq.<hive_id>&day_date=gte.<start>&day_date=lte.<end>

GET /rest/v1/activity_events?hive_id=eq.<hive_id>&order=created_at.desc&limit=50

3B. RPC (SQL functions) — recommend using these

POST /rest/v1/rpc/user_local_date body: { p_user: '<uuid>' } → date

POST /rest/v1/rpc/log_habit body: { p_habit_id:'<uuid>', p_value:1 } → row from habit_logs

POST /rest/v1/rpc/create_hive_from_habit body: { p_habit_id:'<uuid>', p_name:'<optional>', p_backfill_days:30 } → uuid (hive_id)

POST /rest/v1/rpc/create_hive_invite body: { p_hive_id:'<uuid>', p_ttl_minutes:10080, p_max_uses:20 } → row from hive_invites

POST /rest/v1/rpc/join_hive_with_code body: { p_code:'<code>' } → uuid (hive_id)

POST /rest/v1/rpc/log_hive_today body: { p_hive_id:'<uuid>', p_value:1 } → row from hive_member_days

POST /rest/v1/rpc/advance_hive_day body: { p_hive_id:'<uuid>', p_day:'YYYY-MM-DD' } → { advanced, complete_count, required_count }

3C. Nightly advancement (Edge Function/Worker)

At each user’s local midnight + day_start_hour, call advance_hive_day(hive_id, yesterday) for every hive with any activity yesterday.

Push “Hive at risk” at ~20:00 local if some members missing and others done (simple query on hive_member_days).

4) Client screens (what goes on each)

All SwiftUI. Use SF Pro (Text/Display). Corner radius: 16 (cards), 28 (modals). Spacing scale: 8/12/16/24. Haptics on completion.

A. Onboarding (5 steps)

Theme — Pick Honey / Mint / Night. Preview background. (Writes profiles.theme.)

Seed Habits — Choose 2 tiles (Drink Water/Walk/Read/etc.). (Creates habits.)

Day Start & Timezone — Slider 0–6am, timezone auto. (Writes profiles.day_start_hour, timezone.)

Find Friends — Ask Contacts permission; upload phone hashes; show matches (from auth.users.phone). Invite link optional (from create_hive_invite on a temp hive or later in Hive tab).

Auth & Perms — Continue with Phone OTP or Apple. Then Ask Notifications; micro‑tutorial: press & hold → Honey Pour.

B. Habits (Home)

Grid/list of Habit Cards: emoji, name, today’s big hex, mini comb of last 14–30 days.

Actions: Tap to toggle today, Press & hold for pour (counter animates up to target), Long‑press → Edit.

FAB “+” → Create Habit Modal.

C. Create / Edit Habit Modal

Fields: name, emoji, color, type (checkbox/counter), target, schedule (daily or weekmask), reminders (times).

CTA: Create. Secondary: Make a Hive (converts via create_hive_from_habit and shows invite).

D. Habit Details

H1: emoji + name; key stats: current streak, completion %.

Month comb with tappable days (toggle/adjust).

Buttons: Mark Complete, Skip Today. If linked to a hive, show hive status chip.

E. Insights

Overall completion bar, current streaks row, Year Comb per habit (scrollable).

Filter: Week / Month / Year.

F. Hive

Header card: Create Hive / Invite.

Hive List: cards with name, member count, shared streak, today status ring (#done / #required).

Tap hive → Hive Detail:

Member avatars with “done” check marks for today.

Shared Month comb (cells indicate advanced days).

Activity feed (last 20 events).

Buttons: Log Today (calls log_hive_today), Invite (calls create_hive_invite), Advance Now (owner only; optional) for manual re-check.

G. Profile/Settings

Profile card (display name, since when, level).

Toggles: Notifications (system), Apple Health (future), Backup (automatic), Premium (future).

Manage theme, day start, timezone.

Sign out.

5) Design spec (finalized to your mocks)

Brand & UI

Primary Gradient (Honey): #FFD166 → #FF9F1C

Mint Success (cells): #34C759

Bee Black: #1C1C1E (text/dark bg)

Cream Base (light bg): #FFF6E6

Sky Accent: #5AC8FA

Slate Text: #111111

Neutral Grays: #F2F2F7 (cards), #E5E5EA (borders)

Typography

SF Pro Display for titles (Semibold 24–28).

SF Pro Text for body (Regular 15–17), captions (13).

Numbers (streaks) can use SF Mono for a techy feel (optional).

Components

Habit Card: 16pt padding; emoji 40pt; number (today count) large; label; mini comb row.

Comb Cells: rounded 6pt hex/square; 8px gap; state colors (empty, partial, full).

Buttons: Primary uses Honey gradient; secondary white with subtle border.

Modals: 28pt radius; frosted background (iOS blur).

Motion

Honey Pour: press & hold fills today’s cell with a vertical gradient + soft ripple; haptic .soft.

Streak Milestone: confetti burst + tiny bee orbit for 800ms.

Hive Advance: all member check marks pop in sequence; shared hex lights up.

Dark mode

Background #121212; elevate cards with 8% white overlay; keep Honey gradient saturated; mint cells slightly brighter.

Icon/Logo

Hex‑H or Smiley Bee Head for the app icon. Inside app, use SF Symbols where possible.

6) Implementation notes (agent checklist)

Auth

Enable Phone OTP in Supabase; implement signInWithOtp → verifyOtp.

Optionally enable Sign in with Apple; after Apple sign‑in, prompt to link phone for contacts.

Subscribe to onAuthStateChange; on .signedIn load profile/habits/hives; on .tokenRefreshed continue; on .signedOut show OTP screen.

Data

Use RLS‑secured selects for reads.

Writes: prefer RPCs (log_habit, create_hive_from_habit, join_hive_with_code, log_hive_today).

Offline: queue writes; RPCs are idempotent on (habit_id, log_date) / (hive_id, user_id, day_date).

Notifications

Store APNs token in device_tokens.

Edge Function to send pushes on hive_advanced and “at risk” checks.

Nightly job

For each hive with any hive_member_days yesterday, call advance_hive_day(hive_id, yesterday) in users’ local time windows; or run hourly and advance when a day rolls over for any member timezone.

Contacts

Normalize to E.164; hash with a server‑provided pepper; upload to contact_hashes.

Match by comparing to hashed auth.users.phone (you can also hash those via a computed column or do compare client‑side and send proposed matches).

Testing (critical)

Day boundary tests around day_start_hour.

Duplicate log protection (habit_logs unique).

Hive full (10 members) & invite expiry.

Streak reset vs advance logic.

Offline queue replay without double logs.

7) Example flows (pseudo)

Tap log habit

POST /rest/v1/rpc/log_habit { p_habit_id, p_value:1 } → returns row

Update today cell; play Honey Pour; increment local streak counter.

Convert to hive

POST /rest/v1/rpc/create_hive_from_habit { p_habit_id, p_backfill_days:30 } → hive_id

POST /rest/v1/rpc/create_hive_invite { p_hive_id } → show code & share sheet.

Join via code

POST /rest/v1/rpc/join_hive_with_code { p_code } → hive_id

Navigate to Hive Detail; show members.

Log hive today

POST /rest/v1/rpc/log_hive_today { p_hive_id }

If all done, (worker) advance_hive_day → push milestone.

8) Minimal SwiftUI view map (names to create)

OnboardingThemeView, OnboardingSeedHabitsView, OnboardingDayStartView, OnboardingContactsView, OnboardingAuthView

HomeHabitsView (cards)

HabitCreateSheet, HabitEditSheet

HabitDetailView (month comb)

InsightsView

HiveListView, HiveDetailView

ProfileView, SettingsView

Each screen’s data uses a @StateObject service wrapping Supabase SDK; expose async methods for the RPCs above.

That’s it

This export is ready to paste into your tooling. It gives you a tight MVP with phone‑only auth, expandable Hive groups, GitHub‑style grids, and the signature Honey Pour + combined streak loop built in. If you want, I can also output Alembic-style migrations or Deno Edge Function stubs for the nightly job and APNs pushes.
