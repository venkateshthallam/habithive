-- Fix ambiguous column reference in log_hive_today function
-- Use a simpler approach by returning a single row directly

drop function if exists public.log_hive_today(uuid, numeric);

create or replace function public.log_hive_today(
  p_hive_id uuid,
  p_value numeric
)
returns json
language plpgsql security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_today date;
  v_result json;
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

  -- Return the record as JSON
  select row_to_json(t)
  into v_result
  from (
    select
      hmd.hive_id,
      hmd.user_id,
      hmd.day_date,
      hmd.value,
      hmd.done
    from public.hive_member_days hmd
    where hmd.hive_id = p_hive_id
      and hmd.user_id = v_user_id
      and hmd.day_date = v_today
  ) t;

  return v_result;
end $$;

grant execute on function public.log_hive_today(uuid, numeric) to authenticated;
