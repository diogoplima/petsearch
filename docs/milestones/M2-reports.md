# M2 — Reports (photos, geo, list/detail)

**Goal:** a phone files a sighted report — photo + pin — in under 90 seconds
on the deployed app; exact locations verifiably never leak.

## Steps

1. **R2 setup** (manual, document it): create `photos` bucket + an API token
   scoped to that bucket only. Public read via r2.dev or a custom domain for
   GETs (photos are public content by design — they're on public reports).
   Env: account id, key pair, bucket, public base URL.
2. **Presign** (`internal/storage`): aws-sdk-go-v2 S3 client pointed at the
   R2 endpoint; `PresignPut(key, contentType, maxBytes)` with ~10 min expiry.
3. **`POST /v1/uploads/presign`** (auth): server generates keys
   `reports/{uuid}/main.jpg` + `.../thumb.jpg` (client never picks keys),
   constrains content-type `image/jpeg` and size (main ≤ 2 MB, thumb ≤ 100 KB),
   returns both URLs + the key prefix.
4. **Frontend image pipeline** (`web/src/lib/image.ts`): file/camera input →
   `createImageBitmap` (handles EXIF orientation) → canvas → JPEG ~0.82 at
   1600 px long edge + 320 px thumb → PUT both to presigned URLs. Unit-test
   the sizing math with vitest. Re-encode = EXIF/GPS stripped (ADR-0003).
5. **Location step**: `navigator.geolocation.getCurrentPosition` (high
   accuracy, 10 s timeout) pre-fills a draggable MapLibre pin; denial/failure
   → map centered on a sensible default with instruction text. Validate
   lat ∈ [-90,90], lng ∈ [-180,180] server-side too.
6. **`POST /v1/reports`**: validate; one pgx transaction: insert `reports`
   (public fields; photo keys from step 3), insert `report_private`
   (exact_location `st_makepoint(lng, lat)` — lng first! — + optional
   contact_info / notify_email); trigger fills approx_location. Then run
   `find_candidates` and return report + candidates (payload ready for M3's
   UI even if M2 renders it minimally).
   **Anonymous path (ADR-0013)**: `status=sighted` without a session is
   allowed — require a photo, accept optional notify_email, rate-limit
   3/day/IP (and presign similarly). `status=missing` without auth → 401.
   The frontend sighting flow therefore never shows a login gate; the
   missing flow keeps the IndexedDB-draft-through-login dance.
7. **`GET /v1/reports`** (public): filter by status + bbox (`&& ST_MakeEnvelope`)
   or lat/lng+radius; `state='open'` default; keyset pagination
   (`(created_at, id)` cursor). Response uses approx_location only —
   enforce by never selecting private columns in these sqlc queries.
8. **`GET /v1/reports/{id}`**: public fields; include a `private{}` object
   only when caller is owner (M3 extends to confirmed counterparty via
   `CanReveal` — write the function now with just the owner branch).
9. **`PATCH /v1/reports/{id}`** (owner): attributes; state transitions
   open→resolved (sets resolved_at) and open→removed. Reject others.
10. **Frontend screens**: report flow (4 steps per docs/services/web.md,
    IndexedDB draft persistence across the login gate), home list + map
    (fuzzed circles, clustering can wait), detail, my-reports with
    resolve/edit.
11. **The regression test** (non-negotiable): integration test hitting the
    public list + detail as anonymous and as a stranger, asserting the raw
    JSON contains no `exact_location`/`contact_info` and that approx differs
    from exact by 100–250 m.

## Alternatives worth knowing

- **Presigned direct-to-R2** (recommended, ADR-0010) vs **proxying uploads
  through the API**: proxying enables server-side validation of actual bytes
  (magic numbers, future virus scan, server-side thumbnailing) at the cost
  of bandwidth through your VPS and request-size limits. Know this tradeoff
  cold — it's a classic interview topic. Our client-side thumbs are
  spoofable by a hostile client; acceptable: worst case is an ugly image on
  their own report, and M4's removal path covers abuse.
- **Keyset pagination** (recommended) vs offset/limit: offset is simpler and
  fine at small scale but degrades linearly and skips/duplicates rows under
  concurrent inserts. Implement keyset; read about offset so you know what
  you avoided.
- **List filtering**: bbox (recommended for map views — matches what the
  viewport actually is) vs center+radius (natural for "near me" lists).
  Supporting both is cheap; do bbox first.

## Definition of Done

- [ ] 90-second phone test passes on the deployed app (time yourself)
- [ ] regression test (step 11) green in CI
- [ ] photos load fast (thumbs in lists, main only on detail)
- [ ] denied location permission still allows manual-pin reporting
