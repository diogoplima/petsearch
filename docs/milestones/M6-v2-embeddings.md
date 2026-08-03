# M6 (v2) — Embedding worker

**Gate:** do not start until launch data shows candidate pools regularly
exceeding ~30 (ADR-0005), OR you consciously decide to build it as the
learning playground it was designed to be. Either reason is valid — just
know which one you're acting on. Design details: docs/services/worker-embeddings.md.

## Steps

1. **Eval set FIRST**: export confirmed match pairs (positives) and, per
   pair, 10 nearby non-matching reports (negatives) into a fixture. Metric:
   mean rank of the true match under current v1 scoring — that's the
   baseline to beat. No eval set, no embedding term; this ordering is the
   whole point.
2. **Worker scaffold** (`worker/`): Python 3.12, uv or poetry, `open_clip`
   ViT-B/32, psycopg, boto3 (R2). `/healthz` only; Dockerfile; own DB role
   granted SELECT on reports/report_private-free columns + UPDATE on
   `reports.embedding` only.
3. **Queue**: `LISTEN report_created` + periodic sweep of
   `embedding IS NULL AND photo_paths != '{}'`; claim with
   `FOR UPDATE SKIP LOCKED` (the outbox-adjacent pattern from M3's
   alternatives — the rep transfers). Download main photo, embed, write,
   commit. Idempotent by construction.
4. **Backfill** existing reports; watch throughput (CPU ViT-B/32 ≈ 2–10
   img/s — fine).
5. **Migration**: HNSW index on `embedding` (cosine) + new find_candidates
   version adding `+ 0.3 * (1 - (r.embedding <=> src.embedding))` when both
   sides non-null, with other weights rebalanced. Keep the old function
   until step 6 passes.
6. **Measure**: rerun the eval; ship only if mean rank of true matches
   improves. Record the numbers in an ADR (accepted or *rejected* — a
   documented "we measured CLIP and it didn't help" is a fantastic ADR).
7. **Deploy**: container on the Oracle free ARM box (or the VPS if RAM
   allows); healthcheck + Sentry; this service may lag or die without
   affecting the product — blast radius is ranking quality only.

## Alternatives worth knowing

- **Model**: CLIP ViT-B/32 (recommended start: ubiquitous, tiny) vs DINOv2
  (often better pure-visual features — likely the first thing to try if
  CLIP's same-breed discrimination disappoints) vs fine-tuning on pet re-ID
  data (the deep end; a genuinely publishable-blog-post detour, gated on
  the eval set showing the zero-shot models fail).
- **Where inference runs**: server worker (recommended: consistent,
  backfillable) vs in-browser Transformers.js (zero server cost, scales
  with users; costs a ~50–90 MB model download on mobile and trusts client
  output). The browser option is a fascinating architecture — worth a
  spike, probably not the default.
- **Vector index**: HNSW (recommended: better recall/speed, no training
  step) vs IVFFlat (smaller memory, needs data-dependent training). At your
  scale even a sequential scan inside the geo-filtered candidate set is
  fine — the index is partly for learning.

## Definition of Done

- [ ] eval numbers recorded in an ADR, term shipped only on measured improvement
- [ ] worker death does not affect any user-facing flow (test: stop it for a day)
