# ADR-0010: Cloudflare R2 with presigned uploads over VPS-disk storage

**Status:** accepted

## Context
Photos are the heaviest data. Options: local disk on the VPS (simplest),
MinIO self-hosted (more ops surface), or S3-compatible object storage.

## Decision
Cloudflare R2 (10 GB + free egress on the free tier), accessed via
`aws-sdk-go-v2`. Clients upload directly with short-lived presigned PUT URLs;
the API never proxies photo bytes.

## Consequences
- User photos survive VPS rebuilds; backups only need to cover Postgres.
- Free egress removes the classic image-serving cost trap.
- Presigned-URL flow is an industry-standard pattern worth having built.
- Tradeoff vs. MinIO: less self-host purity, far less ops burden; MinIO
  remains the documented option for fully offline dev/self-hosters.
