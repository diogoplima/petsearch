# ADR-0005: Defer image embeddings (CLIP) to v2

**Status:** accepted

## Context
At launch scale, a new report has ~5–30 open counterparts within radius; a
human scanning thumbnails outperforms any ranking model at that volume.
Embedding similarity earns its keep at hundreds of candidates.

## Decision
v1 matching = geo distance + attribute overlap + recency, in SQL. The schema
ships embedding-ready from day one (`reports.embedding vector(512)`, pgvector
enabled) so v2 is a column-fill plus one scoring term — not a migration.
v2 = Python `open_clip` worker (see docs/services/worker-embeddings.md).

## Consequences
- v1 ships weeks earlier with zero inference cost or infra.
- The vector index (HNSW/IVFFlat) is created in v2 once real data exists.
- v2 must include a small eval set of known matched pairs to verify the
  embedding term actually improves ranking before it's trusted.
