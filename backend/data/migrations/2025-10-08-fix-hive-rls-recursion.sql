-- Fix hive-related RLS recursion by routing membership checks through helper functions

-- Helper functions executed as the migration owner (should have bypassrls)
create or replace function public.hive_owner_is(p_hive_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(p_user_id, auth.uid()) is not null
    and exists (
      select 1
      from public.hives h
      where h.id = p_hive_id
        and h.owner_id = coalesce(p_user_id, auth.uid())
    );
$$;

create or replace function public.hive_member_active(p_hive_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(p_user_id, auth.uid()) is not null
    and exists (
      select 1
      from public.hive_members hm
      where hm.hive_id = p_hive_id
        and hm.user_id = coalesce(p_user_id, auth.uid())
        and coalesce(hm.is_active, true)
        and hm.left_at is null
    );
$$;

grant execute on function public.hive_owner_is(uuid, uuid) to anon, authenticated;
grant execute on function public.hive_member_active(uuid, uuid) to anon, authenticated;

-- ========== Hives ==========
-- Replace policies to use helper functions instead of recursive subqueries
drop policy if exists "members read hives" on public.hives;
drop policy if exists "owner manage hive" on public.hives;

drop policy if exists "hive_member_read_access" on public.hives;
drop policy if exists "hive_owner_full_access" on public.hives;

create policy "hive_owner_full_access" on public.hives
  for all using (public.hive_owner_is(id, auth.uid()))
  with check (public.hive_owner_is(id, auth.uid()));

create policy "hive_member_read_access" on public.hives
  for select using (
    public.hive_owner_is(id, auth.uid())
    or public.hive_member_active(id, auth.uid())
  );

-- ========== Hive Members ==========
-- Clean slate for hive_members policies to avoid recursion
drop policy if exists "members read list" on public.hive_members;
drop policy if exists "owner manage members" on public.hive_members;
drop policy if exists "owner add members" on public.hive_members;
drop policy if exists "owner remove members" on public.hive_members;
drop policy if exists "owner insert members" on public.hive_members;
drop policy if exists "members update self" on public.hive_members;
drop policy if exists "members manage self" on public.hive_members;
drop policy if exists "owner update members" on public.hive_members;
drop policy if exists "hive_members_select" on public.hive_members;
drop policy if exists "hive_members_self_insert" on public.hive_members;
drop policy if exists "hive_members_self_update" on public.hive_members;
drop policy if exists "hive_members_owner_manage" on public.hive_members;
drop policy if exists "hive_members_owner_delete" on public.hive_members;
drop policy if exists "hive_members_self_delete" on public.hive_members;

create policy "hive_members_select" on public.hive_members
  for select using (
    public.hive_owner_is(hive_members.hive_id, auth.uid())
    or public.hive_member_active(hive_members.hive_id, auth.uid())
  );

create policy "hive_members_self_insert" on public.hive_members
  for insert with check (
    auth.uid() = user_id
    or public.hive_owner_is(hive_members.hive_id, auth.uid())
  );

create policy "hive_members_self_update" on public.hive_members
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "hive_members_owner_manage" on public.hive_members
  for update using (public.hive_owner_is(hive_members.hive_id, auth.uid()))
  with check (public.hive_owner_is(hive_members.hive_id, auth.uid()));

create policy "hive_members_self_delete" on public.hive_members
  for delete using (auth.uid() = user_id);

create policy "hive_members_owner_delete" on public.hive_members
  for delete using (public.hive_owner_is(hive_members.hive_id, auth.uid()));

-- ========== Hive Member Days ==========
drop policy if exists "member manage own days" on public.hive_member_days;
drop policy if exists "members read all days" on public.hive_member_days;
drop policy if exists "member write own day" on public.hive_member_days;
drop policy if exists "members read days" on public.hive_member_days;
drop policy if exists "hive_member_days_select" on public.hive_member_days;
drop policy if exists "hive_member_days_self_write" on public.hive_member_days;
drop policy if exists "hive_member_days_self_update" on public.hive_member_days;
drop policy if exists "hive_member_days_self_delete" on public.hive_member_days;

create policy "hive_member_days_select" on public.hive_member_days
  for select using (
    public.hive_owner_is(hive_member_days.hive_id, auth.uid())
    or public.hive_member_active(hive_member_days.hive_id, auth.uid())
  );

create policy "hive_member_days_self_write" on public.hive_member_days
  for insert with check (auth.uid() = user_id);

create policy "hive_member_days_self_update" on public.hive_member_days
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "hive_member_days_self_delete" on public.hive_member_days
  for delete using (auth.uid() = user_id);

-- ========== Hive Days ==========
drop policy if exists "members read hive days" on public.hive_days;
drop policy if exists "hive_days_select" on public.hive_days;

create policy "hive_days_select" on public.hive_days
  for select using (
    public.hive_owner_is(hive_days.hive_id, auth.uid())
    or public.hive_member_active(hive_days.hive_id, auth.uid())
  );

-- ========== Hive Invites ==========
drop policy if exists "members read invites" on public.hive_invites;
drop policy if exists "owner create invites" on public.hive_invites;
drop policy if exists "hive_invites_select" on public.hive_invites;
drop policy if exists "hive_invites_insert" on public.hive_invites;

create policy "hive_invites_select" on public.hive_invites
  for select using (
    public.hive_owner_is(hive_invites.hive_id, auth.uid())
    or public.hive_member_active(hive_invites.hive_id, auth.uid())
  );

create policy "hive_invites_insert" on public.hive_invites
  for insert with check (public.hive_owner_is(hive_invites.hive_id, auth.uid()));

-- ========== Activity Events ==========
drop policy if exists "read hive activity" on public.activity_events;

drop policy if exists "hive_activity_select" on public.activity_events;

create policy "hive_activity_select" on public.activity_events
  for select using (
    activity_events.hive_id is not null
    and (
      public.hive_owner_is(activity_events.hive_id, auth.uid())
      or public.hive_member_active(activity_events.hive_id, auth.uid())
    )
  );
