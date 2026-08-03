# ADR-0008: Magic-link auth + opaque DB sessions; no passwords, no JWTs

**Status:** accepted

## Context
The critical user is someone standing next to a found dog wanting to file a
report in 90 seconds; a password-creation form is where they leave. Auth is
also the highest-learning-value component to build from scratch — if scoped
ruthlessly.

## Decision
- Email magic links are the only login: 256-bit `crypto/rand` token, SHA-256
  hash stored, 15-minute expiry, single-use, enumeration-safe responses,
  rate-limited.
- Sessions are opaque random tokens (hash stored server-side) in
  httpOnly/Secure/SameSite=Lax cookies, 30-day sliding expiry, revocable by
  row deletion.
- No JWTs: for a first-party monolith they add statelessness we don't need
  and revocation problems we'd have to solve.
- Explicitly out of scope for v1: passwords, OAuth, passkeys, MFA.

## Consequences
- No password storage at all — an entire vulnerability class deleted.
- Login depends on email deliverability; Resend setup (SPF/DKIM) must be
  solid from day one — acceptable, match notifications already require it.
- Implement against OWASP Authentication + Session Management cheat sheets;
  every flow, including failure paths, ships with tests (CLAUDE.md principle 5).
