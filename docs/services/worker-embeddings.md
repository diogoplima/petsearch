# Service: Embedding worker (v2 — design only)

Do not build until launch + evidence that candidate pools exceed what humans
scan comfortably (ADR-0005).

## Shape

Python 3.12, `open_clip` ViT-B/32 (512-d, CPU is fine: ~100–500 ms/image),
small FastAPI app exposing only `/healthz` (work arrives via DB, not HTTP).

Queue = Postgres, no broker: `reports` rows where `embedding IS NULL` and
photos exist; `LISTEN/NOTIFY` on insert + periodic sweep; claim with
`FOR UPDATE SKIP LOCKED`. Worker downloads the main photo from R2, computes,
writes `embedding`, commits.

## Scoring integration

Add to find_candidates: `+ 0.3 * (1 - (r.embedding <=> src.embedding))` when
both sides have embeddings (rebalance other weights; keep total explainable).
Create the HNSW index in the same migration — data exists by then.

## Validation before trusting it

Maintain a tiny eval set: confirmed match pairs (positives) + adjacent
non-matches (negatives). The embedding term ships only if it measurably
improves mean rank of true matches. If CLIP disappoints (plausible for
same-breed distinction), candidates: DINOv2, or fine-tuning on pet re-ID
datasets — a genuinely interesting ML detour that belongs here, not in v1.

## Deployment

Container on the Oracle free ARM box (or the main VPS if RAM allows), read
access to R2 photos, write access to `reports.embedding` via a dedicated
DB role with minimal grants. This service is the designated playground for
ops experiments — blast radius: ranking quality only.
