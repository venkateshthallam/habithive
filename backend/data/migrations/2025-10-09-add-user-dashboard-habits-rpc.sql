-- Combine personal habits and shared hives for dashboard loading

drop function if exists public.user_dashboard_habits(int);
drop function if exists public.user_dashboard_habits();

create or replace function public.user_dashboard_habits(p_days int default 30)
returns table (
  source text,
  habit_id uuid,
  hive_id uuid,
  name text,
  emoji text,
  color_hex text,
  type public.habit_type,
  target_per_day int,
  schedule_daily boolean,
  schedule_weekmask int,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  owner_id uuid,
  hive_rule text,
  hive_current_length int,
  hive_longest_streak int,
  hive_member_count int,
  source_habit_id uuid
)
language sql
security definer
set search_path = public
as $$
  select
    'personal'::text as source,
    h.id as habit_id,
    null::uuid as hive_id,
    h.name,
    h.emoji,
    h.color_hex,
    h.type,
    h.target_per_day,
    h.schedule_daily,
    h.schedule_weekmask,
    h.is_active,
    h.created_at,
    h.updated_at,
    h.user_id as owner_id,
    null::text as hive_rule,
    null::int as hive_current_length,
    null::int as hive_longest_streak,
    null::int as hive_member_count,
    null::uuid as source_habit_id
  from public.habits h
  where h.user_id = auth.uid()
    and h.is_active = true
    and not exists (
      select 1
      from public.hives hv
      join public.hive_members hm on hm.hive_id = hv.id
      where hv.source_habit_id = h.id
        and coalesce(hv.is_active, true)
        and hm.user_id = auth.uid()
        and coalesce(hm.is_active, true)
        and hm.left_at is null
    )

  union all

  select
    'shared'::text as source,
    null::uuid as habit_id,
    hv.id as hive_id,
    hv.name,
    hv.emoji,
    hv.color_hex,
    hv.type,
    hv.target_per_day,
    hv.schedule_daily,
    hv.schedule_weekmask,
    hv.is_active,
    hv.created_at,
    hv.updated_at,
    hv.owner_id,
    hv.rule,
    hv.current_streak as hive_current_length,
    hv.longest_streak as hive_longest_streak,
    (
      select count(*)
      from public.hive_members hm2
      where hm2.hive_id = hv.id
        and coalesce(hm2.is_active, true)
        and hm2.left_at is null
    )::int as hive_member_count
    ,
    hv.source_habit_id
  from public.hive_members hm
  join public.hives hv on hv.id = hm.hive_id
  where hm.user_id = auth.uid()
    and coalesce(hm.is_active, true)
    and hm.left_at is null
    and hv.is_active = true;
$$;

grant execute on function public.user_dashboard_habits(int) to authenticated;
