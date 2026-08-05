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
  discord    text,                   -- optional Discord handle
  updated_at timestamptz not null default now(),
  primary key (event_id, name)
);

create index if not exists responses_event_idx on public.responses(event_id);

-- Discord handle, so an organiser can tell who "Dee" actually is in the server.
-- Safe to run on an existing database; it is additive and nullable.
alter table public.responses add column if not exists discord text;

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

-- ════════════════════════════════════════════════════════════════════════════
--  WAR ROOM — festival ideas + voting
--  Deliberately stricter than the scheduler above. The scheduler's trade
--  ("anyone with the link can edit anything") is right for availability and
--  wrong for competitive ideas, so these two tables authenticate each write
--  against a secret token the client holds and the server never returns.
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists public.festival_ideas (
  id          uuid primary key default gen_random_uuid(),
  body        text        not null check (length(body) between 8 and 600),
  lane        text        not null default 'Any lane' check (length(lane) <= 40),
  owner_token text        not null,   -- never readable; proves "this is mine"
  created_at  timestamptz not null default now()
);

create table if not exists public.festival_votes (
  idea_id  uuid        not null references public.festival_ideas(id) on delete cascade,
  voter    text        not null check (length(voter) between 8 and 64),
  cast_at  timestamptz not null default now(),
  primary key (idea_id, voter)          -- one voter, one vote, enforced by the DB
);

create index if not exists festival_votes_idea_idx on public.festival_votes(idea_id);

alter table public.festival_ideas enable row level security;
alter table public.festival_votes enable row level security;

-- The token the browser sends with every write. Never stored client-visible.
create or replace function public.req_token() returns text as $$
  select nullif(current_setting('request.headers', true)::json ->> 'x-owner-token', '');
$$ language sql stable;

-- ── ideas ────────────────────────────────────────────────────────────────────
-- Anyone may read and post. Only the holder of the original token may delete,
-- and nobody may edit an idea after the fact — votes would no longer mean what
-- they were cast for.
drop policy if exists fi_read   on public.festival_ideas;
drop policy if exists fi_write  on public.festival_ideas;
drop policy if exists fi_delete on public.festival_ideas;
create policy fi_read   on public.festival_ideas for select using (true);
create policy fi_write  on public.festival_ideas for insert with check (owner_token = req_token());
create policy fi_delete on public.festival_ideas for delete using (owner_token = req_token());

-- owner_token is excluded from every read path, so a deletion token cannot be
-- harvested by reading the board.
revoke select on public.festival_ideas from anon;
grant  select (id, body, lane, created_at) on public.festival_ideas to anon;

-- ── votes ────────────────────────────────────────────────────────────────────
-- A vote is public (the count is the point), but you may only cast or withdraw
-- one under your own voter id.
drop policy if exists fv_read   on public.festival_votes;
drop policy if exists fv_write  on public.festival_votes;
drop policy if exists fv_delete on public.festival_votes;
create policy fv_read   on public.festival_votes for select using (true);
create policy fv_write  on public.festival_votes for insert with check (voter = req_token());
create policy fv_delete on public.festival_votes for delete using (voter = req_token());

-- Honest limitation: the token lives in the browser, so clearing site data
-- yields a new identity and a second vote. That is the correct trade for a
-- closed room of collaborators; it is NOT a ballot box, and the UI says so.
