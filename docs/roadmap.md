# Roadmap

Sized for ~8 h/day full-time. Milestones, not dates — each has a Definition
of Done. Ship order is deliberate: **deploy pipeline first** (walking
skeleton), so every later feature lands on real infrastructure from day one.

Each milestone has a step-by-step implementation guide (with recommended
path + alternatives) in `docs/milestones/M*.md` — build from those; this
file is the summary view.

## M0 — Walking skeleton (≈ 3–4 days)
Repo scaffold (api/, web/, deploy/), custom Postgres image (PostGIS+pgvector),
Docker Compose local dev, Go `/healthz` endpoint, Vite hello-PWA, CI (lint +
test + build), image pushed to GHCR, deployed to the VPS behind Caddy with TLS.
**DoD:** `git push` to main → live at https://yourdomain within minutes;
`make dev` gives a working local stack.

## M1 — Auth (≈ 4–5 days)
Users table, magic-link request + consume endpoints, session issue/refresh/
logout, auth middleware, rate limiting on token requests, Resend integration,
minimal login UI. **DoD:** full test coverage of happy + failure paths
(expired, reused, tampered); a real email logs you in on the deployed app.

## M2 — Reports (≈ 5–6 days)
Migration 0001 applied; presigned R2 upload flow; client-side resize/EXIF
strip; report create (transaction: reports + report_private + fuzz trigger);
report list (map + list views, fuzzed pins) and detail; owner edit/resolve.
**DoD:** a phone can file a sighted report with photo + pin in under 90 s;
exact location verifiably absent from every public API response (test this).

## M3 — Matching + notifications (≈ 5–6 days)
`find_candidates` wired into report flow; "possible matches" UI; match
suggest/confirm/reject endpoints with counterparty authorization; web push
subscribe + send; email notifications; contact/exact-location reveal on
confirm only. **DoD:** two test accounts complete the full reunion flow on
the deployed app; push arrives on Android and installed-iOS; email always.

## M4 — Production hardening (≈ 4–5 days)
Playwright e2e for the core path; Sentry; healthchecks.io; nightly pg_dump →
R2 + one rehearsed restore; structured logging (no PII/coords); basic abuse
guardrails (per-user report rate limit, report-removal admin path); PT + EN
i18n; PWA install prompts; empty states.
**DoD:** you have restored a backup successfully at least once.

## M5 — Launch (Barcelos/Braga) (≈ 1 week, overlapping)
README with screenshots + live URL, CONTRIBUTING, ADRs published, demo video.
Seed the launch: local Facebook groups, vets, shelters, câmara municipal.
**DoD:** 10 real reports from people who aren't you.

## v2 — Embedding worker (post-launch)
Python CLIP worker on Oracle free ARM; backfill embeddings; add cosine term
to scoring; measure whether ranking actually improves (keep a simple
eval set of known matched pairs). This milestone is the devops + ML-ops
playground — take detours here, not in the core.

## Post-launch portfolio track — AWS deployment showcase
Terraform that deploys the app to AWS properly (VPC, ECS or EC2, S3 +
CloudFront, IAM), spun up on the new-account credit tier ($100–200,
6-month window), documented with a diagram + screenshots in
docs/deploy-aws.md, then torn down before the window closes. Purpose:
hands-on AWS + Terraform for the job market and a "infrastructure is
portable, here's proof" artifact — NOT a production migration (prod stays
R2 + Hetzner per ADR-0010/tech-stack; the AWS free plan auto-closes after
6 months, the wrong shape for a permanent service). Do this after M5, when
the README has real users to mention.

## Deliberately not scheduled
OAuth login, moderation dashboard, multi-photo galleries, breed autodetect,
federation, a dog *entity* model (linking multiple sightings as "the
same dog" — the report-centric model stands until launch data shows stray
threads are a real use case), the owner-opt-in **public search trail**
(likely the first post-launch feature — needs its own ADR on fuzzing and
consent), and an **adoption section** (anticipated and hedged, ADR-0015 —
regulatory + vetting questions must be answered first). Each needs evidence
of demand first.
