-- Final fix for hive creation circular dependency
-- This version completely bypasses RLS for the specific create_hive_from_habit function

-- Drop the existing function
drop function if exists public.create_hive_from_habit(uuid, text, text, int);

-- Create a new version that bypasses RLS entirely for internal operations
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

  -- Get habit details - use security definer to bypass RLS
  select id, user_id, name, emoji, color_hex, type, target_per_day, schedule_daily, schedule_weekmask
  into v_habit
  from public.habits
  where id = p_habit_id and user_id = v_user_id;

  if v_habit is null then
    raise exception 'Habit not found or not authorized';
  end if;

  -- Temporarily disable RLS for this session context
  -- Create hive directly without policy checks
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

  -- Add owner as member directly without policy checks
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