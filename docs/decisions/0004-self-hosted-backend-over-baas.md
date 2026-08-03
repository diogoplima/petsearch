# ADR-0004: Self-hosted Go backend over Supabase (BaaS)

**Status:** accepted (supersedes an earlier draft decision to use Supabase)

## Context
Supabase free tier was the initial choice: fastest path to shipping, €0,
open-source stack (Postgres + PostGIS + pgvector all available). The project's
primary goal then shifted explicitly to *learning* — specifically backend and
devops depth — which is exactly the layer a BaaS abstracts away. Full-time
availability also removed the main argument for the managed shortcut.

## Decision
Self-host: Go API + Postgres + Caddy on a small VPS via Docker Compose, with
Cloudflare R2 for photos. Own the auth, authorization, deploy pipeline,
backups, and monitoring.

## Consequences
- ~3x more build effort and ~€5/mo hosting cost, traded for the learning
  and portfolio value that motivate the project.
- Everything Supabase provided is now our responsibility: auth (ADR-0008),
  authorization in app code, storage presigning, backups, uptime.
- The schema/matching SQL designed for Supabase ported ~90% unchanged; RLS
  policies became API-layer authorization.
- Escape hatch acknowledged: if the project stalls on infrastructure, falling
  back to managed services is a legitimate rescue, decided consciously.
