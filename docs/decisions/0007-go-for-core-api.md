# ADR-0007: Go for the core API

**Status:** accepted

## Context
Product quality at this scale is language-agnostic. Maintainer already has
Node/TypeScript (near-zero learning delta), targets the international backend
market, and wants devops depth.

## Decision
Go, stdlib-first (`net/http` 1.22+ ServeMux, pgx, sqlc). TypeScript remains
in the browser; Python arrives in v2 where ML lives — each language where
it's strongest.

## Consequences
- Highest learning delta of the candidate languages; strong EU-remote market
  signal paired with Postgres + self-hosted ops.
- Single static binary → trivially small images, simple deploys — synergy
  with the devops learning goal.
- Cost: a few weeks of ramp; early code will be non-idiomatic and public.
- Escape hatch: reverting to Node is a legitimate rescue if the project
  stalls on language friction (consciously, per ADR-0004's principle).
