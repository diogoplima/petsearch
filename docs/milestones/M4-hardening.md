# M4 — Production hardening

**Goal:** you'd be comfortable with a stranger's lost dog depending on this.
Backups restored at least once, errors observable, core path e2e-tested.

## Steps

1. **Playwright e2e**: one test, the sacred path — user A files missing,
   user B files sighted nearby, B suggests, A confirms, both see reveal.
   Login is automatable via Mailpit's REST API — the test requests a
   magic link, fetches the message from Mailpit, extracts the token, and
   POSTs it. Runs in CI against the parity compose stack.
2. **Error tracking**: Sentry SDK in api (panic recovery middleware reports
   before re-500ing) and web (source maps uploaded in CI). Alert to your
   email. Scrub: no coordinates/emails/tokens in event payloads — configure
   the scrubber, then verify with a deliberate test event.
3. **Backups for real**: `deploy/backup.sh` — `pg_dump -Fc | gzip` →
   `rclone`/aws-cli copy to the backup bucket → curl healthchecks.io ping.
   Cron nightly. **Restore drill**: restore yesterday's dump into a scratch
   container, run the API's test suite against it, write the exact commands
   into docs/services/infra.md. A backup you haven't restored is a hope,
   not a backup.
4. **Uptime**: healthchecks.io check on `/healthz` (or an external monitor)
   + the backup dead-man switch from step 3.
5. **Log audit**: grep the codebase for logging of coordinates, emails,
   contact_info, tokens. Add a lint-ish test if feasible (e.g. a unit test
   asserting the slog handlers redact known keys).
6. **Abuse guardrails**: per-user report creation limit (e.g. 10/day),
   max photo count enforced, and a **removal runbook**: a documented SQL
   procedure (set state='removed', delete R2 objects) you can execute in
   minutes when someone uploads garbage. See alternatives.
7. **Lifecycle job (ADR-0014)**: daily in-process ticker — archive
   sightings >60 d, send "still searching?" nudges (signed one-click link →
   `POST /reports/{id}/still-searching`, single-use token, same pattern as
   auth) at 90 d inactivity, archive unanswered nudges after 14 d, purge
   notify_email on archive/remove. Owner reopen from their report page.
   Tests: state transitions + the purge.
8. **i18n**: externalize all strings (should already be true per the
   frontend skill), ship PT + EN, language auto-detect + manual toggle.
9. **PWA polish**: iOS install sheet after first submission; Android install
   prompt; empty states for list/inbox; offline banner; Lighthouse PWA +
   performance pass on a throttled profile.
10. **Legal minimum**: privacy policy page (what's stored, the fuzzing model,
   contact for removal) and terms stub. You're holding EU users' emails and
   locations — GDPR applies; the honest v1 posture is data minimalism (you
   already have it) + a working delete-my-account path: implement
   `DELETE /v1/me` (cascades are already in the schema; R2 objects need
   explicit deletion).

## Alternatives worth knowing

- **Moderation**: SQL runbook (recommended v1) vs admin endpoints gated by
  an `is_admin` flag vs a dashboard. The runbook costs an hour; the
  dashboard costs a week and has ~0 users on day one. Upgrade path is
  demand-driven. If reports of abuse become weekly, build the endpoint;
  if daily, the dashboard.
- **Error tracking**: Sentry SaaS free tier (recommended: zero ops) vs
  GlitchTip self-hosted (OSS-coherent, one more container to babysit).
  Migrating later is trivial (same SDK protocol) — a rare free reversal.
- **Analytics** (if wanted at all): none (recommended until launch) vs
  self-hosted privacy-friendly (Plausible CE / Umami). If added, it must be
  cookieless and mentioned in the privacy page.

## Definition of Done

- [ ] e2e green in CI
- [ ] you have personally restored a backup and the procedure is documented
- [ ] Sentry catches a deliberately thrown test error from prod, scrubbed
- [ ] delete-my-account works end to end (DB rows + R2 objects gone)
- [ ] PT + EN complete
