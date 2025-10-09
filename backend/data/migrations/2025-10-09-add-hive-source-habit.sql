-- Track the originating habit for hives created from personal routines

alter table public.hives
  add column if not exists source_habit_id uuid;

alter table public.hives
  drop constraint if exists hives_source_habit_id_fkey;

alter table public.hives
  add constraint hives_source_habit_id_fkey
  foreign key (source_habit_id)
  references public.habits(id)
  on delete set null;

create index if not exists idx_hives_source_habit on public.hives(source_habit_id);

-- Backfill using activity events emitted during habit->hive conversion
with source_map as (
  select
    ae.hive_id,
    ((ae.data ->> 'habit_id'))::uuid as habit_id,
    row_number() over (partition by ae.hive_id order by ae.created_at asc) as ordinal
  from public.activity_events ae
  join public.habits hb on hb.id = ((ae.data ->> 'habit_id'))::uuid
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

comment on column public.hives.source_habit_id is 'Original habit that spawned this hive (if any)';
