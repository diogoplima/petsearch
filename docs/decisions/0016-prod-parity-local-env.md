# ADR-0016: Prod-parity local environment with zero-account onboarding

**Status:** accepted

## Context
Confidence that "works locally" means "works deployed" requires the local
stack to match production topology. Simultaneously, contributors must reach
a running, populated app from a fresh clone without creating any external
accounts (Cloudflare, Resend, Hetzner). A single always-containerized mode
would satisfy parity but ruin the daily feedback loop.

## Decision
Two explicit modes, plus prod, all sharing one compose base:
- `make dev` — fast inner loop: compose db (+ stand-ins) only; Go on the
  host with live reload; vite dev server. Optimized for feedback speed.
- `make up` — parity stack: `deploy/compose.yml` (the SAME base file the
  VPS uses) + `compose.local.yml` override: api image built from source,
  Caddy serving the built web bundle with `tls internal` (local CA), and
  open-source stand-ins for external services.
- Prod — same base + `compose.prod.yml`: GHCR image, real domain, real
  secrets.

Stand-ins (in dev and local modes): **MinIO** for R2 (same S3 API — the
presigned-URL path runs for real) and **Mailpit** for Resend (SMTP catcher,
web UI on :8025). Both selected via env through the existing storage/Mailer
interfaces. `.env.example` defaults to the stand-ins; `make seed` loads
sample reports so the app is clickable immediately.

Parity is topological, not absolute: MinIO ≠ R2, Mailpit ≠ deliverability,
local CA ≠ Let's Encrypt, arm64 ≠ amd64. Milestone DoDs therefore still
verify on the deployed instance.

## Consequences
- Drift between local and prod becomes structurally impossible at the
  topology level (shared base file), not a matter of discipline.
- Contributor onboarding: clone → `make up` → populated app; zero accounts,
  zero cost — a practical requirement for an AGPL community project.
- Costs: two more containers, an SMTP Mailer implementation alongside the
  Resend one, and override-file hygiene (anything added to prod compose
  must be reflected or consciously excluded in local).
- Rejected: mocking storage/email in code (leaves the real integration
  paths untested locally) and one containerized-everything mode (slow loop).
