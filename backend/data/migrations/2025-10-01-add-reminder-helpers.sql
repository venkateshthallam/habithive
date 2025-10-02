-- ========= Helper Functions for Habit Reminders =========
-- SQL functions to support push notification scheduling

-- Function to get current time in user's timezone
create or replace function public.user_current_time(p_user_id uuid)
returns time
language sql stable
as $$
  select (now() at time zone coalesce(
    (select timezone from public.profiles where id = p_user_id),
    'UTC'
  ))::time;
$$;

-- Function to get current date in user's timezone (accounting for day_start_hour)
create or replace function public.user_current_date(p_user_id uuid)
returns date
language sql stable
as $$
  select public.user_local_date(p_user_id, now());
$$;

-- Function to get habits that need reminders right now
-- Returns habits where:
-- 1. reminder_enabled = true
-- 2. Current time in user's timezone matches reminder_time (within 1 minute)
-- 3. Habit is scheduled for today
-- 4. Notification hasn't been sent today yet
create or replace function public.get_habits_needing_reminders()
returns table(
  habit_id uuid,
  user_id uuid,
  habit_name text,
  habit_emoji text,
  user_timezone text,
  reminder_time time,
  onesignal_player_ids text[]
)
language plpgsql stable
as $$
begin
  return query
  select
    h.id as habit_id,
    h.user_id,
    h.name as habit_name,
    h.emoji as habit_emoji,
    p.timezone as user_timezone,
    h.reminder_time,
    array_agg(distinct dt.onesignal_player_id) filter (where dt.onesignal_player_id is not null) as onesignal_player_ids
  from public.habits h
  join public.profiles p on p.id = h.user_id
  left join public.device_tokens dt on dt.user_id = h.user_id
  where
    -- Habit has reminders enabled
    h.reminder_enabled = true
    and h.reminder_time is not null
    and h.is_active = true
    and h.is_archived = false
    -- User has notifications enabled
    and p.notification_habits = true
    -- Current time in user's timezone matches reminder_time (within 1 minute window)
    and abs(extract(epoch from (
      (now() at time zone p.timezone)::time - h.reminder_time
    ))) < 60
    -- Habit is scheduled for today (check weekday mask)
    and (
      h.schedule_daily = true
      or (h.schedule_weekmask & (1 << (
        case
          when extract(dow from (now() at time zone p.timezone)::date) = 0 then 6  -- Sunday = 7 -> 6 in 0-indexed
          else extract(dow from (now() at time zone p.timezone)::date)::int - 1
        end
      ))) > 0
    )
    -- Notification hasn't been sent today
    and not exists (
      select 1
      from public.notification_logs nl
      where nl.habit_id = h.id
        and nl.user_id = h.user_id
        and nl.sent_date = public.user_current_date(h.user_id)
        and nl.notification_type = 'habit_reminder'
    )
  group by h.id, h.user_id, h.name, h.emoji, p.timezone, h.reminder_time
  having array_length(array_agg(distinct dt.onesignal_player_id) filter (where dt.onesignal_player_id is not null), 1) > 0;
end $$;

-- Grant execute permissions
grant execute on function public.user_current_time(uuid) to authenticated, anon;
grant execute on function public.user_current_date(uuid) to authenticated, anon;
grant execute on function public.get_habits_needing_reminders() to authenticated, anon;
