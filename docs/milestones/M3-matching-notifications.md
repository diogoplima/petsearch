# M3 — Matching + notifications

**Goal:** two accounts complete the full reunion flow on the deployed app:
report → suggest → notify → confirm → reveal. Push on Android + installed
iOS; email always.

## Steps

1. **`GET /v1/reports/{id}/candidates`** (owner): thin wrapper over
   `find_candidates()`; hydrate the returned ids into public report cards
   (thumb, attributes, coarse distance, score). Also surfaces in the
   create-report response (wired in M2 step 6).
2. **`POST /v1/matches`**: body = both report ids. Authorization: caller
   owns exactly one of the two; both reports `open`; opposite statuses;
   `unique` constraint gives 409 on duplicates. State `pending`,
   `suggested_by` = caller. Emits `match.suggested` event.
3. **`CanReveal(userID, reportID)`** (extend from M2): true if owner, or if
   a `confirmed` match links this report to one the user owns. ONE
   implementation, used by report-detail and any future surface.
4. **Confirm/reject**: only the *counterparty* (the involved user who is not
   `suggested_by`) may decide; sets state + `decided_at`. Confirm emits
   `match.confirmed`. Decide-once: reject re-decides are 409s.
   **Anonymous sightings (ADR-0013)**: no counterparty exists, so the
   missing-report owner decides unilaterally — same endpoints, the
   authorization branch checks `sighted.user_id IS NULL`. Confirm reveals
   the sighting's exact location to the owner and, if notify_email exists,
   emails the anonymous reporter an update (no reveal in that email —
   notify_email receives updates, never private data).
5. **Authorization matrix test** (do it now, not later): {owner-suggester,
   counterparty, stranger, anonymous} × {create, confirm, reject, view} —
   table-driven, one test. Include the anonymous-sighting branch: owner
   can decide unilaterally; a stranger still cannot; notify_email never
   appears in any response JSON (extend the M2 regression test).
6. **Web Push plumbing**: generate a VAPID keypair once (store private key
   as env secret, public key served to the frontend);
   `POST/DELETE /v1/push/subscriptions`; frontend subscribes contextually
   after first report submission (never on page load) and renders pushes in
   the service worker (`push` + `notificationclick` → matches inbox).
7. **`internal/notify`**: `Notify(ctx, userID, event)` fans out to all of a
   user's push subscriptions (webpush-go, TTL ~24 h; on 404/410 responses
   delete the dead subscription) + one email (plain text v1: what happened +
   a link). Events: suggested → counterparty; confirmed → both parties.
8. **Send timing**: v1 sends synchronously in the request *after* the DB
   transaction commits, with a short timeout and errors logged-not-fatal
   (a slow push must never fail a confirm). See alternatives — this is a
   deliberate simplification with a named upgrade path.
9. **Frontend**: matches inbox (pending: side-by-side photo compare +
   confirm/reject; confirmed: revealed exact location pin + contact info),
   badge count, "this could be my dog" button on report detail.
10. **Reveal UI honesty**: confirmed view shows exact pins and contact;
    everywhere else stays circles. Copy should say why ("locations are
    approximate until a match is confirmed, for everyone's safety").
11. **Trail view**: `GET /v1/reports/{id}/trail` (owner of a missing
    report) = confirmed matches joined to sightings, ordered by seen_at;
    frontend draws exact pins + chronological polyline with timestamps.
    One query, one map layer — the payoff of the report-centric model.
    Owner-only; add it to the authorization matrix test (stranger → 403,
    sighted-report owner → 403).

## Alternatives worth knowing

- **Synchronous notify** (recommended v1) vs **transactional outbox**: the
  outbox pattern writes an `outbox` row in the same transaction as the state
  change; a background loop (`FOR UPDATE SKIP LOCKED`) sends and marks done.
  Guarantees no lost notifications on crash between commit and send, adds a
  table + a goroutine. This is THE pattern behind reliable event delivery in
  industry — read about it now, implement it as the designated M4+ stretch
  goal if you want the learning rep (it's also exactly the queue shape the
  v2 worker uses, so the rep transfers).
- **Notification fan-out**: per-event direct send (recommended) vs digesting
  (batch "3 new possible matches" emails). Digests reduce annoyance at
  volume; pointless below it. Revisit with data.
- **Email content**: plain text (recommended v1 — deliverability-friendly,
  zero tooling) vs HTML templates (MJML). A reunion product arguably wants
  a nice confirmed-match email eventually; not before launch.

## Definition of Done

- [ ] full two-account reunion flow on the *deployed* app
- [ ] push received on Android Chrome and installed-iOS Safari; email in both flows
- [ ] dead push subscriptions get pruned (test with a deleted subscription)
- [ ] authorization matrix test green
- [ ] a failed email/push provably cannot fail or roll back a confirm
