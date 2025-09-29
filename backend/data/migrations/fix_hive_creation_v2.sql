-- Fix hive creation circular dependency issue v2
-- Use SECURITY DEFINER to bypass RLS for internal operations

-- Drop and recreate the create_hive_from_habit function with better RLS handling
drop function if exists public.create_hive_from_habit(uuid, text, text, int);

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
  -- Get current user (security definer context)
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  -- Get habit details (bypass RLS since we're checking ownership)
  select * into v_habit
  from public.habits
  where id = p_habit_id and user_id = v_user_id;

  if v_habit is null then
    raise exception 'Habit not found or not authorized';
  end if;

  -- Create hive (this will use the owner_manage_hive policy)
  insert into public.hives(
    name, description, owner_id, emoji, color_hex,
    type, target_per_day, schedule_daily, schedule_weekmask
  )
  values (
    coalesce(p_name, v_habit.name || ' Hive'),
    p_description,
    v_user_id,
    v_habit.emoji,
    v_habit.color_hex,
    v_habit.type,
    v_habit.target_per_day,
    v_habit.schedule_daily,
    v_habit.schedule_weekmask
  )
  returning id into v_hive;

  -- Add owner as member (bypass RLS since we're the owner)
  -- Use a direct insert bypassing policies since we know this is valid
  insert into public.hive_members(hive_id, user_id, role)
  values (v_hive, v_user_id, 'owner');

  -- Backfill recent logs if requested
  if p_backfill_days > 0 then
    insert into public.hive_member_days(hive_id, user_id, day_date, value)
    select v_hive, v_user_id, log_date, value
    from public.habit_logs
    where habit_id = p_habit_id
      and user_id = v_user_id  -- extra safety check
      and log_date >= (current_date - p_backfill_days)
    on conflict do nothing;
  end if;

  -- Create activity event
  insert into public.activity_events(actor_id, hive_id, type, data)
  values (
    v_user_id,
    v_hive,
    'hive_joined',
    jsonb_build_object(
      'habit_id', p_habit_id,
      'habit_name', v_habit.name,
      'created_from_habit', true
    )
  );

  return v_hive;
end $$;

-- Grant execute permission
grant execute on function public.create_hive_from_habit(uuid, text, text, int) to authenticated;

-- Also update the hive_members policies to be more explicit
drop policy if exists "owner manage members" on public.hive_members;
drop policy if exists "members manage self" on public.hive_members;
drop policy if exists "owner update members" on public.hive_members;

-- Simplified hive_members policies
create policy "owner insert members" on public.hive_members
  for insert with check (
    exists (
      select 1 from public.hives h
      where h.id = hive_members.hive_id and h.owner_id = auth.uid()
    )
    or user_id = auth.uid()  -- Allow self-insert for joining hives
  );

create policy "members update self" on public.hive_members
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "owner update members" on public.hive_members
  for update using (
    exists (
      select 1 from public.hives h
      where h.id = hive_members.hive_id and h.owner_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.hives h
      where h.id = hive_members.hive_id and h.owner_id = auth.uid()
    )
  );