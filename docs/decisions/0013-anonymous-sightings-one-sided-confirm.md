# ADR-0013: Anonymous sighting reports with one-sided confirmation

**Status:** accepted (amends the M3 mutual-confirmation flow for one case)

## Context
The most casual, most valuable user is a stranger who spots a dog. Any login
gate — even a 15-second magic link — loses some of them, and losing a
sighting can mean losing a reunion. But accountless reports have no
notification channel back and no counterparty to confirm a match, and they
open a spam surface.

## Decision
- `sighted` reports may be created without an account (`user_id` null;
  enforced: `missing` always requires an owner account).
- Optional `notify_email` (stored in report_private, never revealed, never
  a login): used only for updates — "owner thinks this is their dog",
  "reunited".
- Matching: for anonymous sightings, the missing-report owner confirms
  **unilaterally**, revealing the sighting's exact location to them.
  Justification for the asymmetry: sighting locations are public streets;
  missing-report locations approximate homes. The sensitive direction keeps
  mutual confirmation.
- Spam controls: photo required, per-IP creation limits (e.g. 3/day),
  anonymous reports have no edit/delete UI (lifecycle expiry cleans up,
  ADR-0014), and the M4 removal runbook covers abuse.

## Consequences
- Zero-friction sighting flow — the core funnel widens.
- One-sided confirm weakens mutual verification in one direction; worst
  case is an owner unlocking a street location of a non-matching dog —
  acceptable harm profile.
- notify_email is PII held without an account: covered by the privacy page,
  purged when the report is archived/removed.
- Duplicate sightings by the same anonymous person can't be linked —
  accepted noise.
