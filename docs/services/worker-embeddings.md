# Service: Embedding worker (v2 — design only)

Do not build until launch + evidence that candidate pools exceed what humans
scan comfortably (ADR-0005), OR as the two-tier flagship feature (ADR-0017).

## Shape

Python 3.12, `open_clip` ViT-B/32 (512-d, CPU is fine: ~100–500 ms/image),
small FastAPI app exposing only `/healthz` (work arrives via DB, not HTTP).

Queue = Postgres, no broker: `reports` rows where `embedding IS NULL` and
photos exist; `LISTEN/NOTIFY` on insert + periodic sweep; claim with
`FOR UPDATE SKIP LOCKED`. Worker downloads the main photo from R2, computes,
writes `embedding`, commits. Runs dark from launch day (ADR-0017): every
report gets embedded on arrival regardless of whether tier 2 is enabled yet,
so the index is already populated when tier 2 goes live.

## Scoring integration — two tiers (ADR-0017)

Distance in the v1 design does discrimination work that embeddings can now
do better at any range, so v2 splits matching into two tiers instead of
folding embeddings into `find_candidates` as one more term:

- **Tier 1 (unchanged)**: `find_candidates` stays exactly as v1 — radius-
  bounded (`ST_DWithin`), attribute + proximity + recency scoring, no
  embeddings. High precision, no ML, covers the dominant ran-away case.
- **Tier 2 (new)**: a separate query/endpoint — embedding KNN (HNSW) over
  ALL open counterpart reports, with NO distance filter. Species remains a
  hard filter; geography becomes a scoring feature (log-scale distance
  decay), not a gate, so a strong visual match on the other side of the
  country can outrank a weak nearby one. Create the HNSW index in the same
  migration that adds this query — data exists by then, dark-worker embeds
  having run since launch.

Tier-2 results are never merged into tier-1 results — they render in their
own "possible distant matches" UI section, and a confirmed tier-2 match's
reveal copy directs owners to local authorities rather than self-retrieval,
since a confirmed distant match implies possible theft.

## Validation before trusting it

Per ADR-0017's eval-bootstrapping order:

1. **Offline first**: evaluate the embedding model on public pet re-ID
   datasets before launch — this justifies shipping tier 2 in a
   conservative beta despite the domain shift from curated photos to user
   phone shots.
2. **Own confirmed pairs**: once real matches accumulate, maintain a tiny
   eval set — confirmed match pairs (positives) + adjacent non-matches
   (negatives) — and use it going forward as the eval that earns full
   confidence.

Tier 2 ships only when eval numbers show defensible precision@k against
this ground truth — a fast wrong answer at global scale is a false-hope
generator, not a feature. If CLIP disappoints (plausible for same-breed
distinction), candidates: DINOv2, or fine-tuning on pet re-ID datasets — a
genuinely interesting ML detour that belongs here, not in v1.

## Deployment

Container on the Oracle free ARM box (or the main VPS if RAM allows), read
access to R2 photos, write access to `reports.embedding` via a dedicated
DB role with minimal grants. This service is the designated playground for
ops experiments — blast radius: ranking quality only.
