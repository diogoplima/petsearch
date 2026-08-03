# ADR-0015: Adoption section deferred; cheap hedges taken now

**Status:** accepted (records intent + hedges; the adoption design itself is
deliberately undecided)

## Context
A future adoption section is anticipated: listings for ownerless strays
(natural pipeline: expired sightings → shelter intake → adoptable) and for
rehoming. Structurally it shares entities with lost-and-found (users,
photos, attributes, locations, notifications, moderation) but NOT the
workflow: adoption is a listing/inquiry model, not a matching model —
find_candidates has no meaning for it. It also carries risks lost-and-found
doesn't: rehoming scams, disguised sales, and PT/EU regulation of online
animal listings; the plausible shape is verified shelter/associação
listers, not open peer-to-peer.

## Decision
Do not design or build adoption now. Hedges taken:
1. find_candidates raises on any status outside missing/sighted — a future
   status can never silently enter matching.
2. Status remains an extensible enum; species column (ADR-0012) already
   generalizes the animal.
3. Third-status vs. own-table for adoption is EXPLICITLY undecided — decide
   when real requirements exist (shelter accounts? vetting? inquiry
   threads?), via a superseding ADR.
4. Code discipline: status-pairing logic stays centralized (the matching
   function + one service-level constant), never scattered as binary
   missing/sighted assumptions.

## Consequences
- The door stays open at near-zero cost; no speculative abstraction built.
- Anyone (human or agent) proposing adoption features must start from this
  ADR, including the regulatory/vetting questions.
- Rejected: building a generic "listing type" framework now — speculative
  generality with zero informed requirements.
