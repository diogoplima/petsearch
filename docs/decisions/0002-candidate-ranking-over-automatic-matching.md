# ADR-0002: Candidate ranking + human confirmation over automatic matching

**Status:** accepted

## Context
Visual re-identification of individual dogs is unsolved; two same-breed dogs
are near-identical to any model at varying angle/lighting. Auto-matching
would flood users with false positives and destroy trust.

## Decision
The system only *ranks* candidates (geo + attributes in v1, + embeddings in
v2). A human suggests a match; the counterparty confirms. Notifications and
private-data reveal happen only on confirmation.

## Consequences
- Zero false-positive notifications by construction.
- Scoring can stay simple and transparent; ML becomes an additive ranking
  term, never a decision-maker.
- Requires good "review candidates" UX — the human is the matcher.
