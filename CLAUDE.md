# Dog Finder — CLAUDE.md

Community app to reunite lost dogs with their owners. Users report a dog as
**missing** or **sighted** (photo + attributes + location); the system suggests
candidate matches nearby, a human confirms, and both parties get notified.

Open source (AGPL-3.0). One canonical hosted instance. Built primarily by one
engineer as a learning + portfolio project — code quality, tests, and
documented decisions matter as much as features.

## Repository layout

```
api/        Go backend (auth, reports, matching, notifications)
web/        React + TypeScript PWA (Vite)
worker/     v2: Python CLIP embedding worker (empty until v2)
deploy/     Docker Compose, Caddyfile, deploy scripts
docs/       Architecture, tech stack, roadmap, per-service designs
docs/decisions/   ADRs — read these before questioning a design choice
.claude/skills/   Project skills (Go conventions, DB/migrations, frontend, ADRs)
```

## Core principles (do not violate without an ADR)

1. **Privacy model**: exact locations and contact info live ONLY in
   `report_private`. Everything publicly readable uses `approx_location`
   (fuzzed 100–250 m, deterministic per report). Exact data is exposed only
   between the two parties of a confirmed match. Never log coordinates,
   emails, or contact info.
2. **Human-in-the-loop matching**: the system ranks candidates; it never
   declares a match. Notifications fire only on human confirmation.
3. **No passwords**: auth is magic-link email + opaque DB-backed sessions.
   No JWTs. See ADR-0008.
4. **Boring tech, deliberately**: stdlib-first Go, Postgres for everything
   (relational + PostGIS + pgvector). New dependencies need justification.
5. **Auth code ships with tests** — including failure paths (expired token,
   reused token, tampered cookie). Untested auth does not merge.
6. **Spec-first tests for business logic (ADR-0011)**: tests are written
   from the milestone/service docs BEFORE the implementation, must be seen
   failing (red) before code is written, and are never derived from reading
   the implementation. The human reviews tests as the contract.
7. **Every significant decision gets an ADR** (see the adr-writing skill).

## Commands

```
make dev          # docker compose up db + run api with live reload + vite dev
make test         # go test ./... (unit + testcontainers integration)
make lint         # golangci-lint + eslint + tsc --noEmit
make migrate-new name=...   # create migration pair in api/migrations
make migrate-up   # apply migrations to local db
cd web && npm run e2e       # Playwright
```

## Where to look

- High-level design: `docs/architecture.md`
- Technology choices + rationale: `docs/tech-stack.md`
- Build plan / current milestone: `docs/roadmap.md`
- Step-by-step guide per milestone: `docs/milestones/M*.md` — when
  implementing, follow the **recommended path**; "Alternatives worth
  knowing" blocks are teaching material, not an invitation to build all of
  them
- API details (endpoints, auth flows, authorization rules): `docs/services/api.md`
- Frontend screens + PWA specifics: `docs/services/web.md`
- Infra, deploy, backups: `docs/services/infra.md`

## Style quick-notes

- Go: see `.claude/skills/go-conventions` (triggers automatically).
- SQL/migrations: see `.claude/skills/db-and-migrations`. PostGIS point order
  is (lng, lat) — this WILL bite you.
- Frontend: see `.claude/skills/frontend-conventions`.
- Commits: conventional commits (`feat(api): ...`, `fix(web): ...`).
