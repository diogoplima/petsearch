# Build playbook — driving Claude Code through the milestones

How to turn the milestone docs into working software with an agent, without
losing the learning or the quality bar. The milestone docs are the WHAT;
this file is the HOW-TO-DRIVE.

## Session rules (every milestone)

1. **One milestone = one branch = one (or few) sessions.** Start each in
   the repo root so CLAUDE.md and the skills load.
2. **Spec-first, red-first (ADR-0011)**: for business logic, tests are
   written from the docs BEFORE implementation and must be shown failing.
   Enforce it in the prompt until it's habit.
3. **You review tests as the contract; skim implementation.** Tests are
   short and declarative — audit them hard. Occasionally mutation-check:
   delete a guard, confirm the suite goes red.
4. **Make the agent teach**: you're learning Go — require idiom
   explanations as it goes. Code you can't defend in an interview defeats
   the project's purpose.
5. **Design questions pause the session.** If the agent hits something the
   docs don't answer (product behavior, privacy, scope), decide it in
   docs/ (ADR if significant) first, then resume. Agents improvising
   product decisions inline is how solo projects lose coherence.
6. **Commit at every green checkpoint**, conventional commits. Push daily —
   CI is your second reviewer.
7. End each milestone by walking its **Definition of Done yourself**, by
   hand, on the deployed app where the DoD says so.

## Kickoff prompt template

> Read CLAUDE.md and docs/milestones/<FILE>. Before starting, inspect the
> repo's current state and confirm the prior milestones' Definition of Done
> is actually met — don't assume progress from the docs alone. We're
> implementing this milestone step by step, following the recommended path
> (alternatives are reading material, not build orders). For business-logic
> steps, follow ADR-0011: write the tests first from the docs, run them,
> show me the failures, then STOP for my review before implementing. Explain
> Go idioms and infra concepts as you go — I'm learning. If anything is
> ambiguous or contradicts the docs, stop and ask instead of choosing
> silently. Start with step 1.

Swap <FILE> per milestone. After trust is established (~M2), you may drop
the hard STOP and review tests in the diff instead.

## Per-milestone notes

### M0 — walking skeleton (docs/milestones/M0-walking-skeleton.md)

- Machine setup and repo hygiene (git init, LICENSE, .gitignore, README
  stub, `gh repo create`) are already done for this repo — M0 starts at the
  DB image step.
- Pre-work (you, not the agent): DuckDNS account + subdomain chosen (no
  server yet). VPS creation, hardening, DuckDNS IP update, and Actions
  secrets happen at step 10 — after CI is green.
- Agent work is mostly scaffolding + YAML — few tests; the DoD checklist
  is the test. Expect the migration to need syntax fixes on first
  `migrate up`: that's planned, not failure.
- Checkpoint: YOU push a trivial change and watch it go live. Do not let
  the milestone close on "it should work".

### M1 — auth (docs/milestones/M1-auth.md)

- The learning crown jewel: read the OWASP Authentication + Session
  Management cheat sheets YOURSELF before the session.
- Strictest ADR-0011 enforcement here. The failure-path list in the doc is
  the test list; the concurrency test (two parallel verifies, one wins)
  runs against real Postgres via testcontainers.
- Checkpoint: log in on the deployed app from your phone with a real inbox.

### M2 — reports (docs/milestones/M2-reports.md)

- Pre-work: Cloudflare account, R2 bucket + scoped token.
- Non-negotiable: the privacy regression test (step 11) exists and is
  green before the milestone closes. Time the 90-second phone test
  yourself, outdoors, on mobile data.

### M3 — matching + notifications (docs/milestones/M3-matching-notifications.md)

- The authorization-matrix test lands BEFORE notification plumbing.
- Checkpoint: full two-account reunion flow, deployed, push on your real
  phone (and installed-iOS if available), email both directions.

### Dark pipeline — embedding worker (docs/services/worker-embeddings.md, gate in M6 doc)

- Slot after M3 or M4 (~1 week): worker embeds every report on arrival;
  NO user-facing change. Tier-2 UI stays off until precision@k passes
  (ADR-0017).

### M4 — hardening (docs/milestones/M4-hardening.md)

- Pre-work: Sentry + healthchecks.io accounts; buy the real domain (~€10)
  — Resend needs it verified before strangers can log in.
- The restore drill is done BY YOU. An agent restoring a backup teaches
  you nothing and the DoD says "you have personally restored one".

### M5 — launch (docs/milestones/M5-launch.md)

- Mostly human work: README polish, demo video, outreach. The agent helps
  with copy and the metrics SQL; it cannot pin posts in Facebook groups.

## When things go wrong

- Implementation went sideways mid-step → checkpoint/rewind in the VS Code
  extension, keep the tests, retry against the same red suite.
- Agent "fixed" a failing test by changing the test → reject; the docs are
  the spec, the test encodes it. If the SPEC is wrong, change the doc
  first, then the test, then the code — in that order.
- Stuck > 30 min on environment/tooling weirdness → step out of the agent
  loop and debug it yourself in the terminal; then feed the finding back.
