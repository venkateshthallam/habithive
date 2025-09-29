-- Final fix for all RLS recursion and hive creation issues
-- This migration consolidates all fixes and resolves circular dependencies

-- ========== Helper Functions ==========
-- These functions bypass RLS by using security definer with elevated privileges

-- Drop existing helper functions if they exist (cascade to remove dependent policies)
drop function if exists public.hive_owner_is(uuid, uuid) cascade;
drop function if exists public.hive_member_active(uuid, uuid) cascade;

-- Create helper function to check hive ownership
create or replace function public.hive_owner_is(p_hive_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(p_user_id, auth.uid()) is not null
    and exists (
      select 1
      from public.hives h
      where h.id = p_hive_id
        and h.owner_id = coalesce(p_user_id, auth.uid())
        and h.is_active = true
    );
$$;

-- Create helper function to check active hive membership
create or replace function public.hive_member_active(p_hive_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(p_user_id, auth.uid()) is not null
    and exists (
      select 1
      from public.hive_members hm
      where hm.hive_id = p_hive_id
        and hm.user_id = coalesce(p_user_id, auth.uid())
        and coalesce(hm.is_active, true) = true
        and hm.left_at is null
    );
$$;

-- Grant execute permissions
grant execute on function public.hive_owner_is(uuid, uuid) to anon, authenticated;
grant execute on function public.hive_member_active(uuid, uuid) to anon, authenticated;

-- ========== Clean Slate: Drop All Existing Policies ==========

-- Hives policies
drop policy if exists "members read hives" on public.hives;
drop policy if exists "owner manage hive" on public.hives;
drop policy if exists "hive_member_read_access" on public.hives;
drop policy if exists "hive_owner_full_access" on public.hives;
drop policy if exists "hives_select_policy" on public.hives;
drop policy if exists "hives_insert_policy" on public.hives;
drop policy if exists "hives_update_policy" on public.hives;
drop policy if exists "hives_delete_policy" on public.hives;

-- Hive members policies
drop policy if exists "members read list" on public.hive_members;
drop policy if exists "owner manage members" on public.hive_members;
drop policy if exists "owner add members" on public.hive_members;
drop policy if exists "owner remove members" on public.hive_members;
drop policy if exists "owner insert members" on public.hive_members;
drop policy if exists "members update self" on public.hive_members;
drop policy if exists "members manage self" on public.hive_members;
drop policy if exists "owner update members" on public.hive_members;
drop policy if exists "hive_members_select" on public.hive_members;
drop policy if exists "hive_members_self_insert" on public.hive_members;
drop policy if exists "hive_members_self_update" on public.hive_members;
drop policy if exists "hive_members_owner_manage" on public.hive_members;
drop policy if exists "hive_members_owner_delete" on public.hive_members;
drop policy if exists "hive_members_self_delete" on public.hive_members;

-- Hive member days policies
drop policy if exists "member manage own days" on public.hive_member_days;
drop policy if exists "members read all days" on public.hive_member_days;
drop policy if exists "member write own day" on public.hive_member_days;
drop policy if exists "members read days" on public.hive_member_days;
drop policy if exists "hive_member_days_select" on public.hive_member_days;
drop policy if exists "hive_member_days_self_write" on public.hive_member_days;
drop policy if exists "hive_member_days_self_update" on public.hive_member_days;
drop policy if exists "hive_member_days_self_delete" on public.hive_member_days;

-- Hive days policies
drop policy if exists "members read hive days" on public.hive_days;
drop policy if exists "hive_days_select" on public.hive_days;

-- Hive invites policies
drop policy if exists "members read invites" on public.hive_invites;
drop policy if exists "owner create invites" on public.hive_invites;
drop policy if exists "hive_invites_select" on public.hive_invites;
drop policy if exists "hive_invites_insert" on public.hive_invites;

-- Activity events policies
drop policy if exists "read hive activity" on public.activity_events;
drop policy if exists "hive_activity_select" on public.activity_events;

-- ========== Create New Non-Recursive Policies ==========

-- ========== Hives ==========
create policy "hives_owner_full_access" on public.hives
  for all using (public.hive_owner_is(id, auth.uid()))
  with check (public.hive_owner_is(id, auth.uid()));

create policy "hives_member_read_access" on public.hives
  for select using (
    public.hive_owner_is(id, auth.uid())
    or public.hive_member_active(id, auth.uid())
  );

-- ========== Hive Members ==========
create policy "hive_members_read_access" on public.hive_members
  for select using (
    public.hive_owner_is(hive_members.hive_id, auth.uid())
    or public.hive_member_active(hive_members.hive_id, auth.uid())
  );

create policy "hive_members_join_hive" on public.hive_members
  for insert with check (
    auth.uid() = user_id
    or public.hive_owner_is(hive_members.hive_id, auth.uid())
  );

create policy "hive_members_update_self" on public.hive_members
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "hive_members_owner_manage" on public.hive_members
  for update using (public.hive_owner_is(hive_members.hive_id, auth.uid()))
  with check (public.hive_owner_is(hive_members.hive_id, auth.uid()));

create policy "hive_members_leave_hive" on public.hive_members
  for delete using (auth.uid() = user_id);

create policy "hive_members_owner_remove" on public.hive_members
  for delete using (public.hive_owner_is(hive_members.hive_id, auth.uid()));

-- ========== Hive Member Days ==========
create policy "hive_member_days_read_access" on public.hive_member_days
  for select using (
    public.hive_owner_is(hive_member_days.hive_id, auth.uid())
    or public.hive_member_active(hive_member_days.hive_id, auth.uid())
  );

create policy "hive_member_days_write_own" on public.hive_member_days
  for insert with check (
    auth.uid() = user_id
    and public.hive_member_active(hive_member_days.hive_id, auth.uid())
  );

create policy "hive_member_days_update_own" on public.hive_member_days
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "hive_member_days_delete_own" on public.hive_member_days
  for delete using (auth.uid() = user_id);

-- ========== Hive Days ==========
create policy "hive_days_read_access" on public.hive_days
  for select using (
    public.hive_owner_is(hive_days.hive_id, auth.uid())
    or public.hive_member_active(hive_days.hive_id, auth.uid())
  );

-- ========== Hive Invites ==========
create policy "hive_invites_read_access" on public.hive_invites
  for select using (
    public.hive_owner_is(hive_invites.hive_id, auth.uid())
    or public.hive_member_active(hive_invites.hive_id, auth.uid())
  );

create policy "hive_invites_owner_create" on public.hive_invites
  for insert with check (public.hive_owner_is(hive_invites.hive_id, auth.uid()));

-- ========== Activity Events ==========
create policy "activity_events_hive_read" on public.activity_events
  for select using (
    activity_events.hive_id is not null
    and (
      public.hive_owner_is(activity_events.hive_id, auth.uid())
      or public.hive_member_active(activity_events.hive_id, auth.uid())
    )
  );

-- ========== Update RPC Functions ==========

-- Drop existing functions with their exact signatures
drop function if exists public.create_hive_from_habit(uuid, text, text, int);
drop function if exists public.create_hive_from_habit(uuid, text, int);
drop function if exists public.create_hive_invite(uuid, integer, integer);
drop function if exists public.create_hive_invite(uuid, int, int);
drop function if exists public.join_hive_with_code(text);
drop function if exists public.log_hive_today(uuid, numeric);
drop function if exists public.advance_hive_day(uuid, date);

-- Drop any other variants that might exist
drop function if exists public.create_hive_invite cascade;
drop function if exists public.join_hive_with_code cascade;
drop function if exists public.log_hive_today cascade;
drop function if exists public.advance_hive_day cascade;

create or replace function public.create_hive_from_habit(
  p_habit_id uuid,
  p_name text default null,
  p_description text default null,
  p_backfill_days int default 30
)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_hive uuid;
  v_habit record;
  v_user_id uuid;
begin
  -- Get current user
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  -- Get habit details (this should work with existing habits policies)
  select id, user_id, name, emoji, color_hex, type, target_per_day, schedule_daily, schedule_weekmask
  into v_habit
  from public.habits
  where id = p_habit_id and user_id = v_user_id;

  if v_habit is null then
    raise exception 'Habit not found or not authorized';
  end if;

  -- Create hive (bypasses RLS due to security definer)
  insert into public.hives(
    id,
    name,
    description,
    owner_id,
    emoji,
    color_hex,
    type,
    target_per_day,
    schedule_daily,
    schedule_weekmask,
    current_streak,
    longest_streak,
    is_active,
    created_at,
    updated_at
  )
  values (
    gen_random_uuid(),
    coalesce(p_name, v_habit.name || ' Hive'),
    p_description,
    v_user_id,
    v_habit.emoji,
    v_habit.color_hex,
    v_habit.type,
    v_habit.target_per_day,
    v_habit.schedule_daily,
    v_habit.schedule_weekmask,
    0,
    0,
    true,
    now(),
    now()
  )
  returning id into v_hive;

  -- Add owner as member (bypasses RLS due to security definer)
  insert into public.hive_members(hive_id, user_id, role, joined_at, is_active)
  values (v_hive, v_user_id, 'owner', now(), true);

  -- Backfill recent logs if requested
  if p_backfill_days > 0 then
    insert into public.hive_member_days(hive_id, user_id, day_date, value, created_at)
    select
      v_hive,
      v_user_id,
      log_date,
      value,
      now()
    from public.habit_logs
    where habit_id = p_habit_id
      and user_id = v_user_id
      and log_date >= (current_date - p_backfill_days)
    on conflict do nothing;
  end if;

  -- Create activity event
  insert into public.activity_events(actor_id, hive_id, type, data, created_at)
  values (
    v_user_id,
    v_hive,
    'hive_joined',
    jsonb_build_object(
      'habit_id', p_habit_id,
      'habit_name', v_habit.name,
      'created_from_habit', true
    ),
    now()
  );

  return v_hive;
end $$;

-- Grant execute permission
grant execute on function public.create_hive_from_habit(uuid, text, text, int) to authenticated;

-- ========== Update Other RPC Functions ==========

-- Recreate other hive-related RPC functions with proper security definer context

-- Create hive invite function
create or replace function public.create_hive_invite(
  p_hive_id uuid,
  p_ttl_minutes int default 10080, -- 7 days
  p_max_uses int default 10
)
returns table(
  id uuid,
  hive_id uuid,
  code text,
  created_by uuid,
  expires_at timestamptz,
  max_uses int,
  use_count int,
  created_at timestamptz
)
language plpgsql security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_code text;
  v_invite_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  -- Check if user is hive owner
  if not public.hive_owner_is(p_hive_id, v_user_id) then
    raise exception 'Only hive owner can create invites';
  end if;

  -- Generate unique code
  v_code := encode(gen_random_bytes(6), 'hex');
  v_invite_id := gen_random_uuid();

  -- Insert invite
  insert into public.hive_invites(
    id, hive_id, code, created_by, expires_at, max_uses, use_count, created_at
  ) values (
    v_invite_id,
    p_hive_id,
    v_code,
    v_user_id,
    now() + (p_ttl_minutes || ' minutes')::interval,
    p_max_uses,
    0,
    now()
  );

  -- Return the invite
  return query
  select hi.id, hi.hive_id, hi.code, hi.created_by, hi.expires_at, hi.max_uses, hi.use_count, hi.created_at
  from public.hive_invites hi
  where hi.id = v_invite_id;
end $$;

grant execute on function public.create_hive_invite(uuid, int, int) to authenticated;

-- Join hive with code function
create or replace function public.join_hive_with_code(p_code text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_invite record;
  v_hive_id uuid;
  v_member_count int;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  -- Get invite details
  select hi.*, h.max_members
  into v_invite
  from public.hive_invites hi
  join public.hives h on h.id = hi.hive_id
  where hi.code = p_code
    and hi.expires_at > now()
    and hi.use_count < hi.max_uses;

  if v_invite is null then
    raise exception 'Invalid or expired invite code';
  end if;

  v_hive_id := v_invite.hive_id;

  -- Check if already a member
  if public.hive_member_active(v_hive_id, v_user_id) then
    return v_hive_id; -- Already a member, return success
  end if;

  -- Check member count
  select count(*)
  into v_member_count
  from public.hive_members
  where hive_id = v_hive_id and is_active = true;

  if v_member_count >= v_invite.max_members then
    raise exception 'Hive is full';
  end if;

  -- Add as member
  insert into public.hive_members(hive_id, user_id, role, joined_at, is_active)
  values (v_hive_id, v_user_id, 'member', now(), true);

  -- Increment use count
  update public.hive_invites
  set use_count = use_count + 1
  where id = v_invite.id;

  -- Create activity event
  insert into public.activity_events(actor_id, hive_id, type, data, created_at)
  values (
    v_user_id,
    v_hive_id,
    'hive_joined',
    jsonb_build_object('invite_code', p_code),
    now()
  );

  return v_hive_id;
end $$;

grant execute on function public.join_hive_with_code(text) to authenticated;

-- Log hive today function
create or replace function public.log_hive_today(
  p_hive_id uuid,
  p_value numeric
)
returns table(
  hive_id uuid,
  user_id uuid,
  day_date date,
  value numeric,
  done boolean
)
language plpgsql security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_today date;
begin
  v_user_id := auth.uid();
  v_today := current_date;

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  -- Check if user is member
  if not public.hive_member_active(p_hive_id, v_user_id) then
    raise exception 'Not a member of this hive';
  end if;

  -- Insert or update day record
  insert into public.hive_member_days(hive_id, user_id, day_date, value, done, created_at)
  values (p_hive_id, v_user_id, v_today, p_value, p_value > 0, now())
  on conflict (hive_id, user_id, day_date)
  do update set
    value = excluded.value,
    done = excluded.done,
    updated_at = now();

  -- Return the record
  return query
  select hmd.hive_id, hmd.user_id, hmd.day_date, hmd.value, hmd.done
  from public.hive_member_days hmd
  where hmd.hive_id = p_hive_id
    and hmd.user_id = v_user_id
    and hmd.day_date = v_today;
end $$;

grant execute on function public.log_hive_today(uuid, numeric) to authenticated;

-- Advance hive day function
create or replace function public.advance_hive_day(
  p_hive_id uuid,
  p_day date default current_date
)
returns table(
  advanced boolean,
  complete_count int,
  required_count int
)
language plpgsql security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_complete_count int;
  v_required_count int;
  v_advanced boolean;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  -- Check if user is member
  if not public.hive_member_active(p_hive_id, v_user_id) then
    raise exception 'Not a member of this hive';
  end if;

  -- Count active members
  select count(*)
  into v_required_count
  from public.hive_members
  where hive_id = p_hive_id and is_active = true;

  -- Count completions for the day
  select count(*)
  into v_complete_count
  from public.hive_member_days hmd
  join public.hive_members hm on hm.hive_id = hmd.hive_id and hm.user_id = hmd.user_id
  where hmd.hive_id = p_hive_id
    and hmd.day_date = p_day
    and hmd.done = true
    and hm.is_active = true;

  -- Check if hive advanced
  v_advanced := (v_complete_count = v_required_count and v_required_count > 0);

  -- Update hive streak if advanced
  if v_advanced then
    update public.hives
    set
      current_streak = case
        when last_advanced_on is null or last_advanced_on < p_day then current_streak + 1
        else current_streak
      end,
      longest_streak = case
        when last_advanced_on is null or last_advanced_on < p_day then
          greatest(longest_streak, current_streak + 1)
        else longest_streak
      end,
      last_advanced_on = case
        when last_advanced_on is null or last_advanced_on < p_day then p_day
        else last_advanced_on
      end,
      updated_at = now()
    where id = p_hive_id;
  end if;

  -- Return results
  return query
  select v_advanced, v_complete_count, v_required_count;
end $$;

grant execute on function public.advance_hive_day(uuid, date) to authenticated;