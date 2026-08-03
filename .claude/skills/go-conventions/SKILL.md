---
name: go-conventions
description: Project conventions for all Go code in api/. Use this whenever writing, reviewing, or refactoring any Go code in this repository — handlers, services, middleware, sqlc queries, tests, or main.go — even for small changes. Also use when adding dependencies or designing new endpoints.
---

# Go conventions (api/)

The maintainer is experienced in TS but new to Go. Write idiomatic Go and
briefly flag non-obvious idioms in review comments/explanations (e.g. "zero
values", "accept interfaces, return structs") — this repo doubles as a
learning vehicle.

## Structure & style

- Stdlib first. `net/http` with 1.22+ ServeMux patterns
  (`mux.HandleFunc("POST /v1/reports", h)`). New third-party deps need a
  one-line justification in the PR/commit body; heavyweight frameworks are
  rejected by default (docs/tech-stack.md).
- Layout per docs/services/api.md. Handlers are thin: decode/validate →
  call service → encode. Business rules live in services, SQL in
  `internal/db/queries/*.sql` (sqlc).
- Middleware = `func(http.Handler) http.Handler`. Auth middleware puts the
  user in context via an unexported key + typed accessor.
- Errors: wrap with `fmt.Errorf("doing x: %w", err)`; sentinel errors in the
  owning package (`var ErrNotFound = ...`); map to the error envelope
  `{"error":{"code","message"}}` in one place (httpx). Never leak internal
  error text to clients.
- Config: read env once at startup into a struct; fail fast with a clear
  message listing missing vars.
- Logging: `log/slog`, JSON. NEVER log coordinates, raw emails, tokens, or
  contact info (CLAUDE.md principle 1). Log user IDs, report IDs, hashes.

## Security invariants

- Tokens: 32 bytes from `crypto/rand`, base64url to the user, SHA-256 in DB.
  Single-use via `UPDATE ... WHERE used_at IS NULL ... RETURNING`.
- Sessions: httpOnly, Secure, SameSite=Lax cookie; sliding 30-day expiry.
- Enumeration-safe auth responses: identical body/status whether the email
  exists or not.
- Authorization checks live in named service functions (e.g.
  `matches.CanReveal`) — never inline duplicated checks in handlers.
- Public report responses must never include exact_location/contact_info;
  there is a regression test asserting this on raw JSON — keep it passing.

## sqlc workflow

1. Write/modify SQL in `internal/db/queries/*.sql` with sqlc annotations.
2. `make sqlc` regenerates; never edit generated files.
3. PostGIS/pgvector expressions are fine in queries — that's why sqlc.

## Testing

**Workflow (ADR-0011 — spec-first, non-negotiable for business logic):**
1. Read the milestone doc + docs/services/api.md for the feature. Write the
   test file FIRST, deriving every assertion from those docs — never from
   implementation code (yours or existing).
2. Run the suite and show the new tests failing (red) before implementing.
   A test that was never red proves nothing.
3. Implement until green; refactor with tests as the guardrail.
4. Business logic = auth flows, authorization rules, scoring, privacy
   invariants, state transitions. Wiring/glue and UI layout are exempt from
   the ritual (tests-alongside is fine there); infra is covered by
   milestone DoD checklists instead.
5. When asked to add tests for existing code, prefer working from the spec
   docs, and flag any behavior where implementation and docs disagree
   instead of silently testing the implementation's behavior.

- Table-driven tests; `t.Run` subtests; `t.Parallel()` where safe.
- Integration tests use testcontainers-go with the project's custom DB image
  (PostGIS+pgvector) and run real migrations. DB-touching logic (fuzz
  trigger, find_candidates, token lifecycle) is tested against real
  Postgres, not mocks.
- Auth changes without tests for failure paths (expired/reused/tampered) do
  not merge — CLAUDE.md principle 5.
- Authorization matrix test: {owner, counterparty-pending,
  counterparty-confirmed, stranger, anonymous} × sensitive endpoints.

## Before finishing any task

Run `make lint test`. If you added an endpoint, update
docs/services/api.md's endpoint table in the same change.
