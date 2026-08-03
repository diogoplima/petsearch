# Tech Stack

Every choice below optimizes for three things, in order: (1) shipping a
reliable product, (2) learning value for the maintainer, (3) legibility to
people reading this repo. "Boring" is a feature.

## Backend (`api/`)

| Concern | Choice | Rationale |
|---|---|---|
| Language | Go (latest stable) | Learning delta over existing TS skills; strong intl. market signal; single-binary deploys simplify the ops story we're here to learn |
| HTTP | stdlib `net/http` + enhanced `ServeMux` (1.22+) | Method/path patterns in stdlib made frameworks optional; middleware as plain `func(http.Handler) http.Handler` |
| DB driver | `jackc/pgx/v5` | The de-facto Postgres driver; pool included |
| Query layer | `sqlc` | SQL stays SQL (PostGIS functions work verbatim), Go gets generated type-safe code; better learning than an ORM hiding the database |
| Migrations | `golang-migrate` | Plain `.up.sql`/`.down.sql` files, CLI + library |
| Validation | hand-rolled per handler | Few endpoints; explicit > reflective for learning |
| Web Push | `SherClockHolmes/webpush-go` | VAPID signing; don't hand-roll crypto |
| Email | Resend HTTP API behind a small `Mailer` interface; SMTP impl for local (Mailpit) | Free tier fits (~100/day); the interface is what makes stand-ins and provider swaps trivial |
| Object storage | Cloudflare R2 via `aws-sdk-go-v2` (S3-compatible) | 10 GB + free egress; presigned URLs keep photo bytes off the API |
| Auth | from scratch: magic links + opaque sessions | See ADR-0008; `crypto/rand` tokens, SHA-256 at rest, constant-time compare |
| Testing | `go test` + `testcontainers-go` (real Postgres) | Matching + fuzzing logic is SQL-heavy; mocks would test nothing |
| Lint | `golangci-lint` | Standard |

## Database

Postgres 16 with **PostGIS** (geo) and **pgvector** (v2 embeddings). One
instance, one database. No combined official image exists, so `deploy/db/`
builds `FROM postgis/postgis:16-3.4` + `postgresql-16-pgvector` — a small,
instructive custom image. Coordinates stored as `geography(point, 4326)`;
remember PostGIS point order is **(lng, lat)**.

## Frontend (`web/`)

| Concern | Choice | Rationale |
|---|---|---|
| Framework | React 18 + TypeScript + Vite | Known ground — the learning budget is spent on the backend |
| PWA | `vite-plugin-pwa` (Workbox) | Manifest + service worker; precache shell, network-first API |
| Server state | TanStack Query | Caching/retry for flaky mobile networks |
| Routing | React Router | Boring, fine |
| Maps | MapLibre GL JS + OpenFreeMap tiles | Fully open-source map stack, no API key, no billing surprise; Leaflet is the fallback if MapLibre fights the timeline |
| Validation | Zod | Shared shapes for forms + API responses |
| Images | canvas resize client-side (1600 px + 320 px thumb) | Cuts upload size ~10x; re-encoding strips EXIF/GPS = privacy win |
| E2E | Playwright | The report → match → notify path must have one true end-to-end test |

## Infrastructure (`deploy/`)

| Concern | Choice | Rationale |
|---|---|---|
| Host | Hetzner CX22 (~€4/mo); Oracle Always-Free ARM as €0 alternative | Cheapest reliable EU option; Oracle caveat: capacity/reclaim risk |
| Orchestration | Docker Compose | The right size; Kubernetes would be cosplay (see architecture.md) |
| Local stand-ins | MinIO (=R2) + Mailpit (=email) | Prod-parity local env with zero external accounts for contributors (ADR-0016) |
| Ingress/TLS | Caddy | Automatic Let's Encrypt, 10-line config |
| CI/CD | GitHub Actions: lint → test → build image → push GHCR → SSH deploy | Full pipeline ownership = the devops learning target |
| Backups | nightly `pg_dump | gzip` → R2, 30-day retention, documented restore drill | Free plan for disaster is "there is no disaster plan" — unacceptable for lost-pet data |
| Errors | Sentry free tier (GlitchTip self-host later if desired) | Know about crashes before users tweet them |
| Uptime | healthchecks.io free (dead-man switch for backups too) | Cheap insurance |

## v2 (`worker/`) — design only for now

Python + FastAPI + `open_clip` (ViT-B/32, CPU) computing 512-d image
embeddings; consumes a work queue from Postgres (`LISTEN/NOTIFY` + claim
query), writes back to `reports.embedding`. Deployed as a container on the
Oracle free ARM box. Details: `docs/services/worker-embeddings.md`.

## Explicitly rejected

- **Supabase / BaaS** — reversed decision, see ADR-0004.
- **JWTs** — ADR-0008.
- **Native apps** — ADR-0001.
- **Kubernetes, microservices, message brokers** — no problem at this scale
  that they solve; revisit with evidence.
- **Google Maps** — billing + closed source; MapLibre+OSM is the OSS-coherent choice.
