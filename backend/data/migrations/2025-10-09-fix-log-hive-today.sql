-- Fix log_hive_today upsert logic and response shape
-- - Restore user-local day handling
-- - Stop writing to generated columns
-- - Return a normalized JSON payload (jsonb)

drop function if exists public.log_hive_today(uuid, numeric);
drop function if exists public.log_hive_today(uuid, numeric, timestamptz);

create or replace function public.log_hive_today(
  p_hive_id uuid,
  p_value int default 1,
  p_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_day date;
  v_target int;
  v_value int;
  v_row public.hive_member_days;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if not public.hive_member_active(p_hive_id, v_user_id) then
    raise exception 'Not a member of this hive';
  end if;

  select public.user_local_date(v_user_id, p_at) into v_day;

  select greatest(1, p_value) into v_value;

  select target_per_day
  into v_target
  from public.hives
  where id = p_hive_id;

  if v_target is not null then
    v_value := least(v_value, greatest(1, v_target));
  end if;

  insert into public.hive_member_days(hive_id, user_id, day_date, value)
  values (p_hive_id, v_user_id, v_day, v_value)
  on conflict (hive_id, user_id, day_date)
  do update set value = excluded.value
  returning * into v_row;

  return to_jsonb(v_row);
end $$;

grant execute on function public.log_hive_today(uuid, int, timestamptz) to authenticated;
