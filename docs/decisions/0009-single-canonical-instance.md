# ADR-0009: Single canonical instance over community self-hosting as the model

**Status:** accepted

## Context
"It's open source, communities can run their own instance" sounds appealing
but fragments the database: a dog reported missing on instance A can never
match a sighting on instance B — and matching *is* the product.

## Decision
One canonical hosted instance is the product. Self-hostability exists for
trust, auditability, and contributor dev environments (`make dev` must give
a full local stack) — not as the distribution model.

## Consequences
- Network effects concentrate; matching works across the whole user base.
- We bear hosting costs/ops for the canonical instance (donations/sponsors
  as it grows).
- Launch strategy follows: globally correct architecture, locally
  concentrated launch (Barcelos/Braga first).
