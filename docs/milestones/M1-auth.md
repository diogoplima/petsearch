# M1 — Auth (magic links + sessions)

**Goal:** a real email logs you into the deployed app. Full failure-path test
coverage. This is the highest-learning-value milestone — go slow, read the
OWASP Authentication and Session Management cheat sheets first (seriously,
before writing code).

Schema already exists in 000001 (`users`, `login_tokens`, `sessions`).

## Steps

1. **sqlc setup**: `sqlc.yaml`, first queries in
   `internal/db/queries/auth.sql`: create/consume login token, create
   session, get session+user by hash, touch session, delete session,
   upsert user by email.
2. **Token helpers** (`internal/auth`): `newToken() (raw string, hash []byte)`
   — 32 bytes `crypto/rand`, base64url raw, SHA-256 hash. Unit test:
   uniqueness, hash determinism, raw never equals hash.
3. **Mailer interface**: `type Mailer interface { Send(ctx, to, subject, text) error }`
   with two impls: `resend` (HTTP API, prod) and `smtp` (dev/parity —
   points at the Mailpit container; every magic link appears in its web UI
   at localhost:8025, so local auth needs no email account and no log
   scraping). Config selects by env.
4. **`POST /v1/auth/magic-link`**:
   - normalize email (trim, lowercase); syntactic validation only
   - rate limit: 3/email/hour and 10/IP/hour → respond 429 with Retry-After
   - create token (15 min expiry), send link `https://app/auth/verify?token=...`
   - **always return the same 200 body** regardless of anything
     (enumeration-safe), including on mailer failure (log it, alert later)
5. **`POST /v1/auth/verify`** (body: token):
   - consume atomically: `UPDATE login_tokens SET used_at=now() WHERE
     token_hash=$1 AND used_at IS NULL AND expires_at > now() RETURNING email`
     — zero rows = invalid/expired/reused, one generic error for all three
   - upsert user by email; create session (30 days); set cookie
     `httpOnly; Secure; SameSite=Lax; Path=/`
6. **The link-scanner gotcha** (this is why verify is a POST): corporate and
   consumer email security scanners prefetch GET links, which would consume
   single-use tokens before the human clicks. So the emailed link lands on a
   frontend route that shows a "Continue" button whose click POSTs the token.
   Never make a GET request mutate auth state.
7. **Middleware**: read cookie → hash → load session+user (single query) →
   attach user to context; sliding expiry: if `last_seen_at` older than 24 h,
   bump it and extend `expires_at`. Expired/absent → 401 envelope.
8. **`POST /v1/auth/logout`** (delete session row) and **`GET /v1/me`**.
9. **Cleanup**: startup + daily ticker deleting expired sessions and tokens.
10. **Frontend**: email form → "check your inbox" state → verify route with
    the Continue button → logged-in indicator. Draft-preservation hooks come
    in M2, but build the auth screens stateless-friendly now.
11. **Resend/DNS**: verify your sending domain (SPF + DKIM records) before
    calling this done — magic-link auth is only as good as deliverability.

## Tests (the milestone's real deliverable)

Token: expired / already used / tampered / nonexistent → identical error.
Concurrency: two parallel verifies of one token → exactly one succeeds
(integration test, real Postgres). Session: expired rejected; logout revokes
immediately; cookie flags asserted. Rate limit: 4th email request in an hour
→ 429. Enumeration: response bytes identical for known/unknown email.

## Alternatives worth knowing

- **6-digit OTP code** (type it) instead of a link: immune to link scanners
  by construction, better when email opens on a different device than the
  browser; costs typing friction. Links + POST-verify (recommended) covers
  the scanner problem; OTP is the right pivot if verify-flow analytics show
  cross-device pain.
- **Rate limiting storage**: in-memory `x/time/rate` per key (recommended:
  simple; resets on restart — acceptable) vs Postgres counting (survives
  restarts, works multi-instance; one more query per request). Read about
  both; you'll meet Redis-based limiters in industry — same idea, different
  store.
- **Session extension**: sliding on activity (recommended, chosen) vs fixed
  absolute expiry (simpler, stricter; users re-login monthly regardless).
  Banks do absolute; consumer apps slide. Know why you chose sliding.

## Definition of Done

- [ ] full flow works on the *deployed* app with a real inbox
- [ ] every test above green in CI
- [ ] local auth is instant via Mailpit (magic link visible at localhost:8025, no email account needed)
