# ADR-0011: Spec-first tests for business logic (LLM-aware TDD)

**Status:** accepted

## Context
Much of this codebase is written with an AI coding agent. A test written
after the implementation, by the same model, in the same context, tends to
describe what the code does rather than what the spec intends — enshrining
bugs as expected behavior and producing high-coverage suites with low
epistemic value. Classic TDD addresses this but is ceremony-heavy for glue
code, UI exploration, and infrastructure.

## Decision
- Business logic (auth, authorization, matching/scoring, privacy invariants,
  state transitions): tests are written first, derived exclusively from
  docs/milestones/ and docs/services/, and must be observed failing before
  implementation begins. The maintainer's review effort goes primarily into
  the tests (the contract), with implementation held to satisfying them.
- Wiring, handlers, and UI: tests-alongside once behavior stabilizes.
- Infrastructure: milestone Definition-of-Done checklists serve as the
  (manual) executable spec; no unit-test theater.
- Periodic mutation spot-checks: deliberately break a guarded behavior
  (e.g., remove a token-expiry check) and confirm the suite goes red.

Rejected: post-hoc test generation (the failure mode above); dogmatic
red-green-refactor on all code (ceremony without confidence on infra/UI).

## Consequences
- Independent verification is restored: tests and code have different
  information sources (spec vs. model output).
- The milestone docs become load-bearing — vague specs now surface as
  unwritable tests, which is a feature.
- Slight slowdown on business-logic features; weak tests remain possible
  (an agent can under-assert against a spec), mitigated by human review of
  tests and mutation spot-checks.
