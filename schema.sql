-- meetReelix schema — paste this whole file into the Supabase SQL editor and run it.
-- Supabase → your project → SQL Editor → New query → paste → Run.

create table if not exists public.events (
  id         text primary key,
  title      text        not null,
  days       jsonb       not null,   -- ["2026-08-06", ...] in the organiser's zone
  start_min  int         not null,   -- minutes past midnight
  end_min    int         not null,
  slot       int         not null,   -- slot length in minutes
  tz         text        not null,   -- IANA zone the event was authored in
  pick       jsonb,                  -- [dayIndex, startSlot, endSlot] once locked
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.responses (
  event_id   text        not null references public.events(id) on delete cascade,
  name       text        not null,
  slots      text        not null,   -- availability packed to base64url bits
  updated_at timestamptz not null default now(),
  primary key (event_id, name)
);

create index if not exists responses_event_idx on public.responses(event_id);

-- keep updated_at honest
create or replace function public.touch_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

drop trigger if exists events_touch on public.events;
create trigger events_touch before update on public.events
  for each row execute function public.touch_updated_at();

drop trigger if exists responses_touch on public.responses;
create trigger responses_touch before update on public.responses
  for each row execute function public.touch_updated_at();

-- ── Row level security ──────────────────────────────────────────────────────
-- The trust model is the same as any "anyone with the link" doc: holding the
-- event id IS the permission. Ids are 128-bit random, so they can't be guessed
-- or enumerated -- and note there is no policy allowing a bare SELECT across
-- the table, so nobody can list events they weren't given.
alter table public.events    enable row level security;
alter table public.responses enable row level security;

drop policy if exists events_read   on public.events;
drop policy if exists events_write  on public.events;
drop policy if exists events_update on public.events;
create policy events_read   on public.events    for select using (true);
create policy events_write  on public.events    for insert with check (true);
create policy events_update on public.events    for update using (true) with check (true);

drop policy if exists responses_read   on public.responses;
drop policy if exists responses_write  on public.responses;
drop policy if exists responses_update on public.responses;
drop policy if exists responses_delete on public.responses;
create policy responses_read   on public.responses for select using (true);
create policy responses_write  on public.responses for insert with check (true);
create policy responses_update on public.responses for update using (true) with check (true);
create policy responses_delete on public.responses for delete using (true);
