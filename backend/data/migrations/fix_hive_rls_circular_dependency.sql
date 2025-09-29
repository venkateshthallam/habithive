-- Fix circular dependency in hive RLS policies
-- The issue: "members read hives" policy checks hive_members table,
-- while "owner manage members" policy checks hives table, creating infinite recursion

-- Drop existing problematic policies
drop policy if exists "members read hives" on public.hives;
drop policy if exists "owner manage hive" on public.hives;
drop policy if exists "members read list" on public.hive_members;
drop policy if exists "owner manage members" on public.hive_members;

-- Create non-circular hive policies
-- Owners can always read/write their hives
create policy "owner manage hive" on public.hives
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Members can read hives they belong to
create policy "members read hives" on public.hives
  for select using (
    owner_id = auth.uid() or exists (
      select 1 from public.hive_members m
      where m.hive_id = hives.id and m.user_id = auth.uid() and m.is_active = true
    )
  );

-- Create non-circular hive_members policies
-- Members can read the member list for hives they belong to
create policy "members read list" on public.hive_members
  for select using (
    user_id = auth.uid() or exists (
      select 1 from public.hive_members m
      where m.hive_id = hive_members.hive_id and m.user_id = auth.uid() and m.is_active = true
    )
  );

-- Only owners can add/remove members, but avoid recursion by directly checking owner_id
create policy "owner manage members" on public.hive_members
  for insert with check (
    exists (
      select 1 from public.hives h
      where h.id = hive_members.hive_id and h.owner_id = auth.uid()
    )
  );

-- Allow members to update their own membership status (for leaving)
create policy "members manage self" on public.hive_members
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Allow owners to update any member in their hives
create policy "owner update members" on public.hive_members
  for update using (
    exists (
      select 1 from public.hives h
      where h.id = hive_members.hive_id and h.owner_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.hives h
      where h.id = hive_members.hive_id and h.owner_id = auth.uid()
    )
  );