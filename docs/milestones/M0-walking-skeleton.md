# M0 — Walking skeleton

**Prerequisite:** a set-up machine — see `docs/setup.md` (installs, VS Code
extensions, accounts checklist). The final sanity check there (Part E) must pass
before starting.

**Goal:** `git push` to main deploys a live, TLS-served hello-PWA + `/healthz`
API on the VPS. No features. Everything after this lands on real infra.

## Steps

1. **Repo hygiene**: done via `docs/setup.md` Part B (git init, AGPL
   LICENSE, .gitignore, README stub, publish via `gh repo create`, day-one
   repo settings). Verify its end-state checklist before continuing.
2. **DB image**: `deploy/db/Dockerfile` per docs/services/infra.md
   (postgis + pgvector). Build locally; verify both extensions:
   `docker run --rm <img> psql -U postgres -c "create extension postgis; create extension vector;"`
   (use a throwaway container with POSTGRES_PASSWORD set).
3. **Compose layout (ADR-0016)**: `deploy/compose.yml` base (caddy, api, db,
   minio, mailpit) + `compose.local.yml` and `compose.prod.yml` overrides.
   Dev brings up db + MinIO + Mailpit; parity mode (`make up`) runs the
   full base with the api built from source and Caddy on `localhost` with
   `tls internal`. Healthchecks on db (`pg_isready`) and minio.
4. **Go API skeleton**: `cd api && go mod init github.com/<you>/petsearch`.
   - `internal/config`: read `PORT`, `DATABASE_URL` etc. from env; fail fast
     listing missing vars.
   - `cmd/api/main.go`: slog JSON logger, ServeMux, `GET /healthz` (200) and
     `GET /readyz` (pings DB with a 1s-timeout context), graceful shutdown
     on SIGTERM (`server.Shutdown`) — do graceful shutdown NOW; retrofitting
     it mid-deploy-pipeline is how you learn about dropped requests the bad way.
   - pgx pool created at startup; `/readyz` is its first consumer.
5. **Migrations wiring**: add golang-migrate as a library, run pending
   migrations on startup before serving. Apply `000001_init` — expect to fix
   syntax; that's the point of doing it now.
6. **Web skeleton**: `npm create vite@latest web -- --template react-ts`;
   add `vite-plugin-pwa` with a manifest (name, icons, standalone display);
   a page that fetches `/v1/../healthz` via the dev proxy and shows status.
7. **Makefile** (root): `dev`, `up` (parity stack), `seed` (sample users +
   reports around a fictional neighborhood — stub now, flesh out in M2),
   `test`, `lint`, `migrate-new`, `migrate-up`, `sqlc` (stub for now).
   `make dev` = compose up db+minio+mailpit + api with live reload +
   `vite dev`.
8. **API image**: multi-stage Dockerfile — build stage → `gcr.io/distroless/static`
   final, `CGO_ENABLED=0`. Confirm image is ~15–25 MB.
9. **VPS provision** (checklist, do manually, document in infra.md as you go):
   create server → SSH key only, disable password auth → `ufw allow 22,80,443`
   → unattended-upgrades → install Docker → DNS A record → clone deploy/.
10. **Prod compose + Caddy**: `compose.prod.yml` adds caddy (Caddyfile from
    infra.md) + api service from GHCR image; db with a named volume.
11. **CI** (`.github/workflows/ci.yml`): golangci-lint, `go test ./...`,
    eslint + `tsc --noEmit`, `vite build`. Runs on PRs and main.
12. **CD** (`deploy.yml`, on main after CI): build+push api image to GHCR,
    build web bundle, `scp`/rsync bundle to the Caddy-served dir, SSH
    `docker compose pull && up -d`, then curl `/readyz` and fail the job if
    it's not 200.
13. **Smoke it**: push a trivial change; watch it go live without touching
    the server.

## Alternatives worth knowing

- **Live reload**: `air` (recommended) vs plain `go run` + manual restart vs
  `wgo`. Trivial choice; don't overthink.
- **Final image base**: distroless (recommended: tiny, no shell, secure) vs
  alpine (has a shell — handy for debugging, +5 MB, musl quirks) vs scratch
  (smallest, but you must hand-add CA certs and tzdata — instructive to do
  once, read about it even if you don't).
- **Deploy mechanism**: SSH + compose pull (recommended: you see every
  moving part — the learning goal) vs **Coolify/Dokku** on the VPS
  (self-hosted PaaS; git-push deploys, dashboards — legitimate tool, but it
  re-hides the layer you're here to learn; good to try _after_ you've done
  it manually) vs watchtower auto-pull (less control over when deploys happen).
- **Provisioning**: manual + documented checklist (recommended for one box)
  vs Terraform + cloud-init (the industry answer; a fine stretch goal later —
  don't block M0 on it).

## Definition of Done

- [ ] `make dev` gives a working local stack from a fresh clone
- [ ] `make up` gives the prod-shaped stack (Caddy + built web + api
      container) at https://localhost with zero external accounts
- [ ] Mailpit UI reachable at localhost:8025; MinIO console up
- [ ] migration 000001 applies cleanly (and `migrate down` works)
- [ ] push to main → live at your domain with valid TLS within minutes
- [ ] `/readyz` fails when db is down (test it: `docker stop` the db)
