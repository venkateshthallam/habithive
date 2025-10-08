-- Simplify invite system: remove hive_invites table and only use hives.invite_code

-- Drop hive_invites policies and table
drop policy if exists "hive_invites_read_access" on public.hive_invites;
drop policy if exists "hive_invites_owner_create" on public.hive_invites;
drop table if exists public.hive_invites cascade;

-- Drop old create_hive_invite function
drop function if exists public.create_hive_invite(uuid, int, int);
drop function if exists public.create_hive_invite cascade;

-- Update join_hive_with_code to only use hives.invite_code
drop function if exists public.join_hive_with_code(text);

create or replace function public.join_hive_with_code(p_code text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_hive record;
  v_member_count int;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  -- Find hive by invite code
  select id, max_members
  into v_hive
  from public.hives
  where invite_code = p_code
    and is_active = true;

  if v_hive is null then
    raise exception 'Invalid or expired invite code';
  end if;

  -- Check if already a member
  if public.hive_member_active(v_hive.id, v_user_id) then
    return v_hive.id; -- Already a member, return success
  end if;

  -- Check member count
  select count(*)
  into v_member_count
  from public.hive_members
  where hive_id = v_hive.id and is_active = true;

  if v_member_count >= coalesce(v_hive.max_members, 10) then
    raise exception 'Hive is full';
  end if;

  -- Add as member
  insert into public.hive_members(hive_id, user_id, role, joined_at, is_active)
  values (v_hive.id, v_user_id, 'member', now(), true);

  -- Create activity event
  insert into public.activity_events(actor_id, hive_id, type, data, created_at)
  values (
    v_user_id,
    v_hive.id,
    'hive_joined',
    jsonb_build_object('invite_code', p_code),
    now()
  );

  return v_hive.id;
end $$;

grant execute on function public.join_hive_with_code(text) to authenticated;
