# ADR-0017: Two-tier matching — local-first, global visual tier

**Status:** accepted (supersedes the implicit hard-radius assumption in the
original matching design; refines ADR-0005's v2 scope)

## Context

Stolen or transported pets appear far outside any local radius; a hard
distance cap makes those cases structurally unmatchable. However, global
matching without a visual model is noise ("medium brown dog, worldwide"),
and global-scale ANN search itself is commodity (HNSW over millions of
embeddings = milliseconds) — the scarce, hard, differentiating property is
re-identification PRECISION: distinguishing one dog among thousands of
visually similar ones. Distance in the v1 design was doing discrimination
work; removing it transfers that burden entirely to embedding quality.

The project's innovation is correctly located at re-identification quality
(model choice, fine-tuning, eval rigor), not search throughput.

## Decision

- **Tier 1 (v1):** bounded local matching exactly as designed —
  ST_DWithin radius, attribute + proximity + recency scoring. High
  precision, no ML, covers the dominant ran-away case.
- **Tier 2 (v2 — the flagship):** global visual matching — embedding KNN
  (HNSW) over ALL open counterpart reports with NO distance filter.
  Geography becomes a scoring feature, not a gate: log-scale distance
  decay term, so strong visual matches at any distance can surface above
  weak nearby ones. Species remains a hard filter (not a scoring term).
- Tier-2 results render in a separate, explicitly lower-confidence UI
  section ("possible distant matches"), never mixed into tier-1 results.
- The embedding worker runs **dark from launch day** — embedding every
  report on arrival, index accumulating silently, no user-facing change —
  so the global tier can be enabled quickly once validated.
- Eval bootstrapping order: (1) offline on public pet re-ID datasets
  before launch (justifies a conservative beta — domain shift from curated
  photos to user phone shots is real); (2) own confirmed-match pairs
  accumulating from real users (the eval that earns full confidence).
- Tier 2 ships only when the eval shows defensible precision@k.
  A fast wrong answer at global scale is a false-hope generator, not a
  feature — precision is the launch gate, not throughput.
- Confirmed distant matches imply possible theft: reveal copy for those
  directs owners to local authorities rather than self-retrieval.

## Consequences

- Worldwide capability without worldwide noise; the stolen/transported
  case becomes matchable.
- Schema impact: zero — the embedding column and HNSW index are
  location-agnostic; find_candidates remains tier-1; tier 2 is a new
  v2 query behind its own endpoint.
- False-positive management becomes the central v2 discipline. Tier-2
  confidence thresholds are tuned conservative-first and relaxed with
  evidence.
- The confirmed-match flow (ADR-0002) is now also the data engine for
  the innovation: every human-verified pair is a ground-truth training
  example for re-identification.
- Rejected: hard global search in v1 (attribute-only = noise flood);
  raising tier-1 radius as a compromise (dilutes local precision without
  covering theft); treating speed as the innovation claim (commodity).
