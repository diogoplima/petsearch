# ADR-0014: Report lifecycle — expiry, re-affirmation, archived ≠ resolved

**Status:** accepted

## Context
Without a lifecycle, stale reports rot the map and pollute matching: months-
old sightings are useless, and abandoned missing reports accumulate. Also,
"a sighting was confirmed" must never be conflated with "the dog is home" —
a missing report legitimately collects multiple confirmed sightings over
time (a trail), and only the owner declares the search over.

## Decision
States: `open` → `resolved` (owner-declared reunion — the success metric) |
`archived` (expired, outcome unknown — distinct category, never counted as
a reunion) | `removed` (owner deletion / moderation).

Lifecycle rules (daily job, M4):
- Sightings: auto-archive 60 days after `seen_at`.
- Missing: at 90 days of inactivity (`last_active_at`), email the owner a
  "still searching?" nudge containing a signed one-click link; an
  affirmative bumps `last_active_at` and keeps the report open
  indefinitely (repeat nudges each further 90 days). No response within
  14 days → archive.
- Confirming a match never changes report state; resolve is always an
  explicit owner action. Archived reports leave listings and matching but
  remain visible via direct link with an "archived" banner.
- On archive/remove: purge anonymous `notify_email` (data minimalism).

## Consequences
- The map and candidate pools stay fresh by default; reunions stay a
  trustworthy metric because unknown outcomes are categorized separately.
- Costs one scheduled job, one email template, one signed-link endpoint.
- An inattentive owner's active search could archive at day ~104 —
  mitigated by the nudge + trivial un-archive (owner can reopen from their
  report page, bumping last_active_at).
