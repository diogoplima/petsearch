# ADR-0006: AGPL-3.0 license

**Status:** accepted

## Context
The project is open source for trust (users share location data; auditable
code matters), contributors, and donation eligibility. Main licensing risk:
a company running a closed commercial clone of a civic project.

## Decision
AGPL-3.0. Anyone operating a modified version as a network service must
publish their modifications.

## Consequences
- Defends against closed SaaS forks; MIT would not.
- Some companies won't contribute or embed AGPL code — acceptable; this is
  an end-user service, not a library.
- Hard to change once external contributions exist (would need CLA or
  unanimous consent) — decided now, deliberately.
