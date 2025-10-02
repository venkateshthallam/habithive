-- ========= Notification Logs Table =========
-- Stores history of all push notifications sent to users

create table if not exists public.notification_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  habit_id uuid not null references public.habits(id) on delete cascade,
  notification_type text not null default 'habit_reminder' check (notification_type in ('habit_reminder', 'streak_milestone', 'test')),
  sent_at timestamptz not null default now(),
  sent_date date not null, -- Date in user's timezone when notification was sent
  onesignal_id text, -- OneSignal notification ID for tracking
  status text not null default 'sent' check (status in ('sent', 'failed', 'delivered')),
  error_message text,
  metadata jsonb default '{}'::jsonb -- Additional data like message content, etc.
);

-- Indexes for efficient querying
create index if not exists idx_notification_logs_user on public.notification_logs(user_id, sent_at desc);
create index if not exists idx_notification_logs_habit on public.notification_logs(habit_id, sent_at desc);
create index if not exists idx_notification_logs_sent_date on public.notification_logs(sent_date desc);
create index if not exists idx_notification_logs_onesignal on public.notification_logs(onesignal_id) where onesignal_id is not null;

-- Composite index for deduplication check
create index if not exists idx_notification_logs_dedup on public.notification_logs(habit_id, user_id, sent_date);

-- RLS policies
alter table public.notification_logs enable row level security;

-- Users can read their own notification logs
do $$ begin
  drop policy if exists "read own notification logs" on public.notification_logs;
exception when others then null;
end $$;

create policy "read own notification logs" on public.notification_logs
  for select using (user_id = auth.uid());

-- Only backend service can insert notification logs (via service role key)
-- No policy needed for insert as it will be done via service role
