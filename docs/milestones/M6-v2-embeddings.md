# M6 (v2) — Embedding worker & two-tier matching

**Gate:** do not start until launch data shows candidate pools regularly
exceeding ~30 (ADR-0005), OR you consciously decide to build it as the
learning playground it was designed to be. Either reason is valid — just
know which one you're acting on. Design details: docs/services/worker-embeddings.md,
ADR-0017 (two-tier matching — read it first, it reshapes this milestone).

Per ADR-0017, v2 ships **two tiers**, not one scoring tweak:

- **Tier 1** stays exactly as v1 built it — radius-bounded `find_candidates`,
  unchanged.
- **Tier 2** is new: a global, distance-*unfiltered* embedding KNN over all
  open counterpart reports, with its own endpoint and its own
  lower-confidence UI section. Geography becomes a scoring feature (log-scale
  decay) instead of a hard gate.

## Steps

1. **Offline eval FIRST (pre-launch bootstrap)**: before any real user data
   exists, evaluate candidate embedding models on a public pet re-ID dataset
   to get a conservative baseline and justify shipping tier 2 in beta. This
   is the ADR-0017 eval-bootstrapping step (1) — separate from and earlier
   than the confirmed-pairs eval below.
2. **Own eval set (step 2 of ADR-0017's bootstrap)**: once real confirmed
   matches exist, export them as positives and, per pair, 10 nearby
   non-matching reports as negatives into a fixture. Metric: mean rank of
   the true match. This is the eval that earns full confidence and the one
   that gates any threshold changes going forward. No eval set, no
   embedding term — this ordering is the whole point.
3. **Worker scaffold** (`worker/`): Python 3.12, uv or poetry, `open_clip`
   ViT-B/32, psycopg, boto3 (R2). `/healthz` only; Dockerfile; own DB role
   granted SELECT on reports/report_private-free columns + UPDATE on
   `reports.embedding` only. Runs **dark from launch day** — embeds every
   report on arrival, index accumulates silently, no user-facing change —
   so tier 2 can be enabled quickly once validated.
4. **Queue**: `LISTEN report_created` + periodic sweep of
   `embedding IS NULL AND photo_paths != '{}'`; claim with
   `FOR UPDATE SKIP LOCKED` (the outbox-adjacent pattern from M3's
   alternatives — the rep transfers). Download main photo, embed, write,
   commit. Idempotent by construction.
5. **Backfill** existing reports; watch throughput (CPU ViT-B/32 ≈ 2–10
   img/s — fine).
6. **Migration**: HNSW index on `embedding` (cosine). Two separate query
   paths, both keeping their weights explainable:
   - Tier 1: `find_candidates` unchanged (still `ST_DWithin`-gated).
   - Tier 2: a new function/endpoint — embedding KNN over ALL open
     counterpart reports (species still a hard filter, no distance gate),
     with a log-scale distance-decay scoring term so strong visual matches
     at any distance can outrank weak nearby ones.
7. **Tier-2 UI**: candidate cards render in a separate, explicitly
   lower-confidence section ("possible distant matches"), never mixed into
   tier-1 results. Reveal copy for confirmed distant matches directs owners
   to local authorities (possible theft), not self-retrieval.
8. **Measure and gate**: rerun both evals (offline re-ID + own confirmed
   pairs). Tier 2 ships to users only when it shows defensible precision@k
   — precision is the launch gate, not throughput. Record the numbers in an
   ADR (accepted or *rejected* — a documented "we measured CLIP and it
   didn't help" is a fantastic ADR).
9. **Deploy**: container on the Oracle free ARM box (or the VPS if RAM
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
  step) vs IVFFlat (smaller memory, needs data-dependent training). Tier 2
  searches ALL open counterpart reports globally (no geo prefilter), so the
  index isn't optional here the way it might be at tier-1 scale.

## Definition of Done

- [ ] offline re-ID eval recorded before tier 2 goes live, even in beta
- [ ] own confirmed-pairs eval numbers recorded in an ADR, tier 2 shipped
      only on measured improvement
- [ ] tier-1 results and tier-2 results never render mixed together in the UI
- [ ] confirmed distant-match reveal copy points to local authorities
- [ ] worker death does not affect any user-facing flow (test: stop it for a day)
