---
name: adr-writing
description: How and when to write Architecture Decision Records in docs/decisions/. Use whenever a significant technical choice is being made or changed — new dependency, changed data model, altered security/privacy behavior, swapped technology, new service — and whenever the user asks to document a decision or the conversation contains a debated tradeoff worth recording.
---

# Writing ADRs

ADRs are a first-class deliverable of this project (portfolio value: they
expose reasoning, which code cannot). Existing records: docs/decisions/.

## When to write one

Write an ADR when a decision (a) is expensive to reverse, (b) constrains
future work, (c) touches the privacy model or auth, or (d) rejects a popular
default (that last one is where the best ADRs live). Do NOT write ADRs for
trivia — library patch bumps, formatting, naming.

If a change contradicts an existing ADR, the new ADR states
"supersedes ADR-NNNN" and the old one's status becomes
"superseded by ADR-MMMM". Never silently violate a standing ADR — CLAUDE.md
principle 6.

## Template

```markdown
# ADR-NNNN: <decision as a verb phrase>

**Status:** accepted | superseded by ADR-MMMM

## Context
2–5 sentences. The forces at play, including constraints (budget, learning
goals, timeline) — honest ones, not sanitized ones.

## Decision
What we chose, concretely. Include the rejected alternatives by name.

## Consequences
Both directions: what this buys, what it costs, what it forbids, and any
explicit escape hatch. Consequences that are risks name their mitigation.
```

## Style

- Number sequentially (next after the highest in docs/decisions/).
- One page max. If it needs more, the decision is probably several decisions.
- Write consequences honestly — an ADR with no downsides listed is
  advertising, not a record.
- Filename: `NNNN-kebab-case-title.md`.
