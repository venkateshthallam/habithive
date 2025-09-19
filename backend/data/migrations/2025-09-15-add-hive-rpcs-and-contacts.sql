-- ========= Add Missing RPCs and Contacts =========
-- Adds: contact_hashes table + RLS, log_hive_today RPC, advance_hive_day RPC

-- Phone-hash table for contact matching (store only hashes)
create table if not exists public.contact_hashes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  contact_hash text not null,   -- sha256(pepper || e164)
  display_name text,
  imported_at timestamptz not null default now(),
  unique(user_id, contact_hash)
);

alter table public.contact_hashes enable row level security;
do $$ begin
  drop policy if exists "owner manage contacts" on public.contact_hashes;
exception when others then null; end $$;
create policy "owner manage contacts" on public.contact_hashes
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Mark/Upsert a member's day in a hive (today by default)
create or replace function public.log_hive_today(p_hive_id uuid, p_value int default 1, p_at timestamptz default now())
returns public.hive_member_days
language plpgsql security definer
set search_path = public
as $$
declare
  v_date date;
  rec public.hive_member_days;
begin
  select public.user_local_date(auth.uid(), p_at) into v_date;

  insert into public.hive_member_days(hive_id, user_id, day_date, value)
  values (p_hive_id, auth.uid(), v_date, greatest(1, p_value))
  on conflict (hive_id, user_id, day_date)
  do update set value = excluded.value
  returning * into rec;

  return rec;
end $$;

grant execute on function public.log_hive_today(uuid, int, timestamptz) to authenticated;

-- Aggregate a hive for a given day and maybe advance shared streak
create or replace function public.advance_hive_day(p_hive_id uuid, p_day date)
returns table(advanced boolean, complete_count int, required_count int)
language plpgsql security definer
set search_path = public
as $$
declare
  v_required int;
  v_done int;
  v_advanced boolean := false;
  v_last date;
begin
  select count(*) into v_required from public.hive_members where hive_id = p_hive_id and is_active = true;
  select count(*) into v_done from public.hive_member_days where hive_id = p_hive_id and day_date = p_day and done = true;

  insert into public.hive_days(hive_id, day_date, complete_count, required_count, advanced)
  values (p_hive_id, p_day, v_done, v_required, false)
  on conflict (hive_id, day_date)
  do update set complete_count = excluded.complete_count, required_count = excluded.required_count;

  if v_done = v_required and v_required > 0 then
    update public.hive_days set advanced = true where hive_id = p_hive_id and day_date = p_day;
    select last_advanced_on into v_last from public.hives where id = p_hive_id;

    if v_last is null or v_last < p_day then
      update public.hives
      set current_streak = current_streak + 1,
          longest_streak = greatest(longest_streak, current_streak + 1),
          last_advanced_on = p_day,
          updated_at = now()
      where id = p_hive_id;
    end if;

    v_advanced := true;

    insert into public.activity_events(actor_id, hive_id, type, data)
    values (auth.uid(), p_hive_id, 'hive_advanced', jsonb_build_object('day', p_day))
    on conflict do nothing;
  end if;

  return query select v_advanced, v_done, v_required;
end $$;

grant execute on function public.advance_hive_day(uuid, date) to authenticated;

