-- 000001_init.up.sql — Dog Finder schema (self-hosted; authorization lives in
-- the API layer, see docs/services/api.md). Ported from the earlier Supabase
-- draft: RLS removed, own auth tables added.

create extension if not exists postgis;
create extension if not exists vector;

create type report_status as enum ('missing', 'sighted');
create type report_state  as enum ('open', 'resolved', 'archived', 'removed');
create type match_state   as enum ('pending', 'confirmed', 'rejected');
create type dog_size      as enum ('small', 'medium', 'large');

-- ---------------------------------------------------------------------------
-- Auth (magic links + opaque sessions, ADR-0008)
-- ---------------------------------------------------------------------------
create table users (
  id           uuid primary key default gen_random_uuid(),
  email        text not null unique,          -- store lowercased
  display_name text not null default 'Anonymous',
  created_at   timestamptz not null default now()
);

create table login_tokens (
  token_hash bytea primary key,               -- sha256(raw token)
  email      text not null,
  expires_at timestamptz not null,
  used_at    timestamptz,
  created_at timestamptz not null default now()
);
create index login_tokens_email_idx on login_tokens (email, created_at);

create table sessions (
  token_hash   bytea primary key,             -- sha256(raw token)
  user_id      uuid not null references users (id) on delete cascade,
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at   timestamptz not null
);
create index sessions_user_idx on sessions (user_id);

-- ---------------------------------------------------------------------------
-- Reports: public row + private row (privacy model, CLAUDE.md principle 1)
-- ---------------------------------------------------------------------------
create table reports (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references users (id) on delete cascade,  -- null = anonymous sighting
  status          report_status not null,
  state           report_state  not null default 'open',
  species         text not null default 'dog',  -- launch is dogs-only; column is the expansion hedge (ADR-0012)
  dog_name        text,
  breed           text,
  colors          text[] not null default '{}',
  size            dog_size,
  eye_color       text,
  marks           text,
  description     text,
  photo_paths     text[] not null default '{}',
  approx_location geography(point, 4326),     -- set by trigger only
  seen_at         timestamptz not null default now(),
  last_active_at  timestamptz not null default now(), -- bumped by owner activity / "still searching" (ADR-0014)
  embedding       vector(512),                -- dormant until v2 (ADR-0005)
  created_at      timestamptz not null default now(),
  resolved_at     timestamptz,
  constraint missing_requires_owner check (status = 'sighted' or user_id is not null)
);
create index reports_approx_location_idx on reports using gist (approx_location);
create index reports_status_state_idx    on reports (status, state);
create index reports_user_idx            on reports (user_id);

create table report_private (
  report_id      uuid primary key references reports (id) on delete cascade,
  exact_location geography(point, 4326) not null,
  contact_info   text,          -- owner-provided; revealed only on confirmed match
  notify_email   text           -- anonymous reporter's optional update channel; NEVER revealed (ADR-0013)
);
create index report_private_location_idx on report_private using gist (exact_location);

-- Deterministic fuzz (100–250 m, hash-seeded) so repeated reads can't be
-- averaged back to the true point.
create function fuzz_location() returns trigger
language plpgsql as $$
declare
  seed   double precision;
begin
  seed := (hashtext(new.report_id::text)::bigint % 100000) / 100000.0;
  update reports
     set approx_location = st_project(
           new.exact_location, 100 + seed * 150, seed * 2 * pi())::geography
   where id = new.report_id;
  return new;
end;
$$;

create trigger on_report_private_written
  after insert or update of exact_location on report_private
  for each row execute function fuzz_location();

-- ---------------------------------------------------------------------------
-- Matches
-- ---------------------------------------------------------------------------
create table matches (
  id                uuid primary key default gen_random_uuid(),
  missing_report_id uuid not null references reports (id) on delete cascade,
  sighted_report_id uuid not null references reports (id) on delete cascade,
  suggested_by      uuid references users (id) on delete set null,
  state             match_state not null default 'pending',
  score             real,
  created_at        timestamptz not null default now(),
  decided_at        timestamptz,
  unique (missing_report_id, sighted_report_id)
);

-- ---------------------------------------------------------------------------
-- Web push subscriptions
-- ---------------------------------------------------------------------------
create table push_subscriptions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users (id) on delete cascade,
  endpoint   text not null unique,
  p256dh     text not null,
  auth       text not null,
  created_at timestamptz not null default now()
);
create index push_subscriptions_user_idx on push_subscriptions (user_id);

-- ---------------------------------------------------------------------------
-- Candidate matching. Uses exact locations internally; callers (the API)
-- expose only coarse distance. v2 adds an embedding similarity term here.
-- ---------------------------------------------------------------------------
create function find_candidates(
  p_report_id uuid,
  p_radius_m  double precision default 15000,
  p_limit     int default 20
)
returns table (report_id uuid, distance_km numeric, score real)
language plpgsql stable as $$
declare
  src     reports;
  src_loc geography;
  want    report_status;
begin
  select * into src from reports where id = p_report_id;
  if not found then
    raise exception 'report not found';
  end if;

  select exact_location into src_loc
    from report_private rp where rp.report_id = p_report_id;

  -- Matching is defined ONLY for the missing<->sighted pair. Future
  -- statuses (e.g. adoption listings, ADR-0015) must fail loudly here,
  -- never silently produce matches.
  want := case src.status
            when 'missing' then 'sighted'::report_status
            when 'sighted' then 'missing'::report_status
          end;
  if want is null then
    raise exception 'matching not defined for status %', src.status;
  end if;

  return query
  select r.id,
         round((st_distance(rp.exact_location, src_loc) / 1000.0)::numeric, 1),
         (
           (1.0 - st_distance(rp.exact_location, src_loc) / p_radius_m) * 0.5
           + case when r.breed is not null and r.breed = src.breed then 0.2 else 0 end
           + case when r.size  is not null and r.size  = src.size  then 0.1 else 0 end
           + (cardinality(
                array(select unnest(r.colors) intersect select unnest(src.colors))
              )::real * 0.1)
           + greatest(0, 0.1 - extract(epoch from now() - r.seen_at)
                             / (30 * 86400) * 0.1)
         )::real
  from reports r
  join report_private rp on rp.report_id = r.id
  where r.status = want
    and r.species = src.species
    and r.state  = 'open'
    and r.id    <> p_report_id
    and st_dwithin(rp.exact_location, src_loc, p_radius_m)
  order by 3 desc
  limit p_limit;
end;
$$;
