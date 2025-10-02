-- ========= Setup pg_cron for Habit Reminders =========
-- Creates a cron job that calls the backend API every minute to send reminders

-- Enable pg_cron extension (requires superuser/admin)
create extension if not exists pg_cron;

-- Enable pg_net extension for making HTTP requests
create extension if not exists pg_net schema extensions;

-- Create net schema wrapper if it doesn't exist
do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'net') then
    create schema net;
  end if;
end $$;

-- Create wrapper function in net schema that matches our desired signature
create or replace function net.http_post(
  url text,
  headers jsonb default '{}'::jsonb,
  body jsonb default '{}'::jsonb
) returns bigint as $$
  select extensions.http_post(url, body, headers);
$$ language sql;

-- Unschedule existing job if it exists (to avoid duplicates)
select cron.unschedule('habit-reminders-job') where exists (
  select 1 from cron.job where jobname = 'habit-reminders-job'
);

-- Schedule the cron job to run every minute
-- This will call your backend API endpoint to process and send reminders
select cron.schedule(
  'habit-reminders-job',           -- Job name
  '* * * * *',                      -- Every minute
  $$
  select net.http_post(
    url := 'https://habithive-production.up.railway.app/api/notifications/send-reminders',
    headers := '{"Content-Type": "application/json", "X-Service-Key": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV6bHJ1YWN3eGd0Y3Vub3h0dHRhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Nzg2NzA2NSwiZXhwIjoyMDczNDQzMDY1fQ.xo9X6Nh4kyAAUyiTxBJdKJJ7iWA5kVMuJtHLzjt9v6A"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);

-- To view all scheduled cron jobs:
-- SELECT * FROM cron.job;

-- To unschedule this job (if needed):
-- SELECT cron.unschedule('habit-reminders-job');

-- To view cron job run history:
-- SELECT * FROM cron.job_run_details WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'habit-reminders-job') ORDER BY start_time DESC LIMIT 10;

-- IMPORTANT NOTES:
-- 1. Replace YOUR_BACKEND_API_URL with your actual backend URL (e.g., https://api.habithive.com)
-- 2. Replace YOUR_SERVICE_KEY_HERE with a secure service key (same as in your backend .env)
-- 3. Make sure the backend endpoint /api/notifications/send-reminders is deployed and accessible
-- 4. On Supabase, you can run this migration via the SQL editor in the dashboard
-- 5. The pg_cron extension requires database admin/superuser privileges
