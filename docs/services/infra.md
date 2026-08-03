# Service: Infrastructure

The devops learning target. Everything reproducible from this repo.

## Topology

One VPS (Hetzner CX22 ~€4/mo, or Oracle Always-Free ARM as the €0 option —
mind its capacity/reclaim caveats). Docker Compose runs:

```
caddy      # ingress, automatic TLS, serves web/ static build, proxies /v1 → api
api        # Go binary, distroless/scratch image
db         # custom image: postgis/postgis:16-3.4 + postgresql-16-pgvector
```

`deploy/db/Dockerfile` (the custom image is necessary — no official image
ships PostGIS _and_ pgvector together):

```dockerfile
FROM postgis/postgis:16-3.4
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-16-pgvector && rm -rf /var/lib/apt/lists/*
```

Caddyfile sketch:

```
petsearch.example {
    handle /v1/* {
        reverse_proxy api:8080
    }
    handle {
        root * /srv/web
        try_files {path} /index.html
        file_server
    }
    encode zstd gzip
}
```

## Environments (ADR-0016)

One compose base, thin overrides — parity by shared files, not copies:

```
deploy/compose.yml         # topology: caddy, api, db (+ minio, mailpit profiles)
deploy/compose.local.yml   # parity mode: build api from source, localhost + tls internal, stand-ins on
deploy/compose.prod.yml    # VPS: GHCR image, real domain, real secrets
```

Three modes:

- **`make dev`** — fast inner loop: compose brings up db + MinIO + Mailpit;
  the Go api runs on the host with air; `vite dev` serves web. Sub-second
  feedback; not prod-shaped, deliberately.
- **`make up`** — local parity: the same base file the VPS runs. Caddy
  serves the built web bundle over HTTPS via its internal CA (trust the
  local root once with `caddy trust` for a green padlock) and proxies /v1
  to the containerized api. What you see here is what the VPS does.
- **Prod** — base + prod override on the VPS.

Stand-ins for external services (dev + parity; zero accounts for
contributors): **MinIO** as the S3/R2 endpoint — presigned URLs exercised
for real — and **Mailpit** catching all email with a web UI at
`localhost:8025` (magic links land there; the api's SMTP Mailer impl points
at it). `.env.example` defaults to the stand-ins so `git clone && make up
&& make seed` yields a running, populated app with no signups. `make seed`
loads sample users + reports clustered around a fictional neighborhood.

Prod secrets live in an untracked `.env` on the server (sops-age later if
it starts hurting). Config fails fast on missing vars in every mode.

Parity caveat (be honest with yourself): MinIO ≠ R2, Mailpit ≠ real
deliverability, local CA ≠ Let's Encrypt, and Apple Silicon arm64 ≠ the
VPS's amd64 — which is why milestone DoDs still verify on the deployed app.

## CI/CD (GitHub Actions)

1. `ci.yml` on PR: golangci-lint, `go test ./...` (testcontainers runs in
   Actions fine), eslint + `tsc --noEmit`, vitest, web build.
2. `deploy.yml` on main: build api image + web bundle → push to GHCR →
   SSH to VPS → `docker compose pull && docker compose up -d` → smoke-check
   `/readyz`. Migrations run on api startup (golang-migrate as library),
   which is fine for a single instance.

## Backups — non-negotiable

Nightly cron on the VPS: `pg_dump | gzip` → R2 (separate bucket from photos),
30-day retention, pinged through healthchecks.io (dead-man switch: silence =
alert). **A backup is not a backup until restored:** M4 includes one
rehearsed restore to a scratch container, and the procedure lives in this
file when written. Photos in R2 are already off-box; no VPS state matters
except Postgres.

## Observability

- Sentry free tier in api + web.
- healthchecks.io: uptime ping on `/healthz` + the backup dead-man.
- Structured logs (slog, JSON) to journald/docker logs. **Never log:**
  coordinates, emails beyond hashed/truncated form, tokens, contact info.

## Security baseline

- VPS: SSH keys only, ufw (80/443/22), unattended-upgrades, fail2ban.
- App rate limits per api.md; Caddy adds nothing fancy in v1.
- R2 keys scoped: api key can presign photo bucket; backup key writes the
  backup bucket only.
