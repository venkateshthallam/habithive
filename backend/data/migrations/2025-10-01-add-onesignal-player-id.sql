-- ========= Add OneSignal Player ID to Device Tokens =========
-- Update device_tokens table to support OneSignal integration

-- Add OneSignal player_id column
alter table public.device_tokens
add column if not exists onesignal_player_id text;

-- Add index for OneSignal player_id lookups
create index if not exists idx_device_tokens_onesignal on public.device_tokens(onesignal_player_id)
  where onesignal_player_id is not null;

-- Add unique constraint to prevent duplicate OneSignal player IDs
create unique index if not exists idx_device_tokens_onesignal_unique on public.device_tokens(onesignal_player_id)
  where onesignal_player_id is not null;
