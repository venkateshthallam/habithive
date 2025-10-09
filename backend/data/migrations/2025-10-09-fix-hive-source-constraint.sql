-- Allow linked habits to be deleted while keeping the hive pointer
-- and rerun the backfill only when the habit still exists.

alter table public.hives
  drop constraint if exists hives_source_habit_id_fkey;

alter table public.hives
  add constraint hives_source_habit_id_fkey
  foreign key (source_habit_id)
  references public.habits(id)
  on delete set null;

with source_map as (
  select
    hv.id as hive_id,
    ((ae.data ->> 'habit_id'))::uuid as habit_id,
    row_number() over (partition by hv.id order by ae.created_at asc) as ordinal
  from public.hives hv
  join public.activity_events ae
    on ae.hive_id = hv.id
  join public.habits h
    on h.id = ((ae.data ->> 'habit_id'))::uuid
  where ae.type = 'hive_joined'
    and (ae.data ->> 'created_from_habit')::boolean = true
    and ae.data ? 'habit_id'
)
update public.hives h
set source_habit_id = sm.habit_id
from source_map sm
where h.id = sm.hive_id
  and sm.ordinal = 1
  and h.source_habit_id is null;
