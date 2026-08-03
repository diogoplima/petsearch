---
name: db-and-migrations
description: Rules for any database work — writing or modifying migrations, SQL queries, PostGIS/geography expressions, pgvector usage, indexes, or schema changes. Use whenever touching files in api/migrations/ or internal/db/, and whenever a task mentions locations, coordinates, distance, matching, embeddings, or schema.
---

# Database & migrations

Postgres 16 + PostGIS + pgvector (custom image in deploy/db/). Migrations via
golang-migrate, run automatically on api startup.

## Migration rules

- `make migrate-new name=add_x` creates `NNNNNN_add_x.up.sql` + `.down.sql`.
  Every up has a working down.
- **Never edit an applied migration.** Schema fixes are new migrations,
  always — even during development, to keep the habit honest.
- Idempotent guards (`if not exists`) only in 000001; later migrations
  should fail loudly if state is unexpected.
- Enums: extend with `alter type ... add value` (note: not usable in the
  same transaction as inserts using the new value).

## PostGIS gotchas (these WILL bite)

- Point constructors take **(lng, lat)** — longitude first. Every historical
  bug in every geo app is this. When writing `st_makepoint`, add a comment:
  `-- (lng, lat)`.
- Use `geography(point, 4326)`, not `geometry` — geography gives meters in
  `st_distance`/`st_dwithin` without projection math.
- `st_dwithin(geog, geog, meters)` is index-assisted; `st_distance(...) < x`
  is not. Filter with dwithin, then order by distance.
- GiST indexes on every geography column that gets filtered.
- The fuzz trigger must remain **deterministic per report** (hash-seeded);
  random re-fuzzing enables averaging attacks. Don't "improve" it with
  random().

## pgvector (dormant until v2 — ADR-0005)

- `reports.embedding vector(512)` exists but stays NULL in v1.
- Do NOT create a vector index in v1 (built from data; empty index is
  pointless). v2 migration adds HNSW + the scoring term together.
- Cosine distance operator is `<=>`; similarity = `1 - distance`.

## Privacy invariants at the schema level

- Exact locations and contact_info exist ONLY in report_private.
- reports.approx_location is written only by the trigger — no code path may
  set it directly.
- Any new table or column carrying location/contact data goes on the private
  side and gets flagged for review + an ADR if it changes the model.

## Query conventions

- All app queries live in internal/db/queries/*.sql for sqlc — no string-
  concatenated SQL in Go, ever.
- Prefer `... FOR UPDATE SKIP LOCKED` for any future queue-style claims
  (the v2 worker uses this pattern).
- When changing find_candidates weights, update docs/services/api.md and
  the scoring unit tests in the same change.
