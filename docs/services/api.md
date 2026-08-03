# Service: API (Go)

Single Go binary. Stdlib `net/http` with 1.22+ ServeMux patterns; pgx/v5 +
sqlc; golang-migrate. See docs/tech-stack.md for rationale.

## Package layout

```
api/
├── cmd/api/main.go          # wiring: config, pool, router, graceful shutdown
├── internal/
│   ├── config/              # env parsing, fail-fast validation
│   ├── httpx/               # middleware (auth, ratelimit, logging, recover),
│   │                        # request helpers, error envelope
│   ├── auth/                # magic links, sessions, mailer interface
│   ├── reports/             # handlers + service for reports & candidates
│   ├── matches/             # suggest/confirm/reject + reveal rules
│   ├── notify/              # web push + email senders
│   ├── storage/             # R2 presigning
│   └── db/                  # sqlc generated code + queries/*.sql
├── migrations/              # golang-migrate .up.sql / .down.sql
└── Makefile
```

## Endpoints (v1)

| Method & path | Auth | Notes |
|---|---|---|
| `POST /v1/auth/magic-link` | – | body: email. Always 200 (enumeration-safe). Rate-limited: 3/email/hour, 10/IP/hour |
| `POST /v1/auth/verify` | – | body: token. Consumes token, sets session cookie |
| `POST /v1/auth/logout` | ✓ | deletes session row |
| `GET  /v1/me` | ✓ | profile + open report counts |
| `POST /v1/uploads/presign` | ✓* | returns presigned PUT URLs (main+thumb); content-type/length constrained. *Anonymous allowed when creating a sighted report — same IP limits as report creation |
| `POST /v1/reports` | ✓* | creates report + private row in one tx; responds with report + top candidates. *`status=sighted` may be anonymous (ADR-0013): photo required, optional notify_email, per-IP limit 3/day; `status=missing` always requires auth |
| `GET  /v1/reports` | – | filters: status, species, bbox or lat/lng+radius, state=open default; paginated; **fuzzed locations only** |
| `GET  /v1/reports/{id}` | – | public fields; embeds `private` object only for owner or revealed counterparty (CanReveal); archived reports render with banner |
| `PATCH /v1/reports/{id}` | owner | edit attrs; `state` transitions open→resolved/removed, archived→open (reopen bumps last_active_at) |
| `POST /v1/reports/{id}/still-searching` | signed link | body: signed token from the nudge email; bumps last_active_at (ADR-0014). Same single-use token pattern as auth |
| `GET  /v1/reports/{id}/candidates` | owner | wraps find_candidates() |
| `GET  /v1/reports/{id}/trail` | owner | missing reports only: confirmed sightings (exact locations + seen_at) ordered chronologically — derived entirely from confirmed matches, no new tables |
| `POST /v1/matches` | ✓* | body: missing_report_id + sighted_report_id; caller must own one side. *Anonymous allowed only from the create-response screen of their own fresh sighting (short-lived signed token issued with the create response binds them to that report); suggested_by null; per-IP limited |
| `POST /v1/matches/{id}/confirm` | counterparty* | fires notifications, unlocks reveal. *If the sighted report is anonymous, the missing-report owner confirms unilaterally (ADR-0013); notify_email, if present, gets an update |
| `POST /v1/matches/{id}/reject` | counterparty* | same anonymous rule |
| `POST /v1/push/subscriptions` | ✓ | store endpoint+keys |
| `DELETE /v1/push/subscriptions/{id}` | owner | |
| `GET /healthz` | – | liveness; `GET /readyz` checks DB |

Error envelope: `{"error": {"code": "string", "message": "human text"}}`,
correct HTTP status. Never leak internals in messages.

## Auth details (per ADR-0008)

- Magic token: 32 bytes `crypto/rand`, sent as base64url in the link; DB
  stores SHA-256, `expires_at = now()+15m`, `used_at` null → single-use
  enforced by `UPDATE ... WHERE used_at IS NULL RETURNING`.
- Session: same token pattern, 30-day sliding (`last_seen_at` bump, extend
  when >24 h since last extension). Cookie: `httpOnly; Secure;
  SameSite=Lax; Path=/`.
- Lookups by hash; comparisons on server-generated hashes (no timing oracle
  on raw tokens). New user auto-created on first verified email.

## Authorization rules (was RLS; now middleware + service checks)

- Public reads return only `reports` public columns; `approx_location` only.
- `report_private` readable by: owner, or counterparty of a **confirmed**
  match involving that report. Anonymous-sighting reveal follows ADR-0013.
  This rule lives in ONE function (`matches.CanReveal(userID, reportID)`)
  — never inline it. `notify_email` is excluded from EVERY read path,
  including reveal — it exists only for the notify package.
- Mutations: owner-only, checked in handlers, tested. Anonymous reports
  have no mutation path (lifecycle expiry is their cleanup, ADR-0014).
- Lifecycle job (daily): archive stale sightings (60 d), nudge stale
  missing (90 d inactivity, signed still-searching link), archive
  unanswered nudges (14 d), purge notify_email on archive/remove.
- **Regression test required:** public list/detail responses must never
  contain `exact_location` or `contact_info` (assert on raw JSON).

## Matching

`find_candidates(report_id, radius_m, limit)` SQL function (migration 0001):
opposite status, `open`, `ST_DWithin` on exact locations, scored by proximity
(0.5) + breed (0.2) + colors (0.1/overlap) + size (0.1) + recency decay (0.1).
Returned to clients with coarse distance only. v2 adds
`+ w * (1 - (embedding <=> src.embedding))` when both embeddings exist.

## Testing strategy

- Unit: token lifecycle, scoring math, authorization matrix
  (owner/counterparty-pending/counterparty-confirmed/stranger × every endpoint).
- Integration (testcontainers, real Postgres): migrations apply cleanly,
  fuzz trigger produces 100–250 m deterministic offset, find_candidates
  ordering, the never-leak-private regression test.
- One Playwright e2e (in web/) covers report → suggest → confirm → reveal.
