-- ========= Profiles Phone & Hive Invite Code =========

-- Add phone column to profiles if missing
alter table public.profiles
  add column if not exists phone text;

-- Ensure phone values are normalized/unique
update public.profiles p
set phone = au.phone
from auth.users au
where p.id = au.id and p.phone is null and au.phone is not null;

create unique index if not exists idx_profiles_phone_unique
  on public.profiles (phone)
  where phone is not null;

-- Add invite_code column for quick sharing if missing
alter table public.hives
  add column if not exists invite_code text unique
  default encode(gen_random_bytes(6), 'hex');

update public.hives
set invite_code = encode(gen_random_bytes(6), 'hex')
where invite_code is null;

-- Touch updated_at when invite_code generated (if column exists)
update public.hives
set updated_at = now()
where invite_code is not null
  and updated_at < now() - interval '1 microsecond';
