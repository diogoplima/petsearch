# Service: Web (React PWA)

React 18 + TS + Vite + vite-plugin-pwa. TanStack Query for server state.
MapLibre GL + OpenFreeMap tiles. Zod at API boundaries.

## Screens

1. **Home** — toggle list/map of open reports near the user (fuzzed pins,
   clustered). Filter: missing/sighted. Primary CTA: "Report a dog".
2. **Report flow** (the product's heart; must finish in <90 s on a phone):
   - Step 1: missing or sighted? → photo (camera capture or gallery)
   - Step 2: location — auto from `navigator.geolocation`, always shown as a
     draggable pin; graceful manual placement if permission denied
   - Step 3: attributes (breed autocomplete, color chips, size, marks,
     description, dog name if missing) — everything optional except photo+pin
   - Step 4 (result): "possible matches nearby" — candidate cards straight
     from the create response, each with a one-tap "I think this is this
     dog" that creates the match suggestion on the spot (M3). INVARIANT:
     the report is always created first; candidate selection augments it
     and never replaces it — a sighting is a trail data point even when it
     matches. Never add a "check if this dog exists" step before
     submission. The sighting flow has no login gate at all (ADR-0013);
     anonymous reporters can still one-tap suggest (suggested_by null,
     owner confirms as usual). The missing flow gates at 3→submit, and the
     draft must survive the login roundtrip (persist to IndexedDB).
3. **Report detail** — photos, attributes, fuzzed map circle (not a pin —
   honesty about imprecision), "this could be my dog / the dog I saw" button
   → creates match suggestion.
4. **Matches inbox** — pending suggestions to review (side-by-side compare),
   confirmed matches showing revealed exact location + contact.
5. **Trail view** (owner, on their missing report): confirmed sightings as
   exact pins connected chronologically with timestamps — "last seen"
   becomes "path so far". Owner-only in v1; any public sharing is a future
   opt-in feature with its own ADR, never a default.
6. **Auth** — email field, "check your inbox" state, verify landing route.
7. **My reports** — edit, mark resolved ("reunited! 🎉" is the metric that
   matters), delete.

## PWA specifics

- Precache app shell; network-first for API; cache-first for map tiles and
  R2 thumbnails (bounded cache).
- Install prompts: Android `beforeinstallprompt`; iOS gets an instructional
  sheet — **required** because iOS push only works installed (ADR-0001).
  Trigger the iOS sheet after first report submission, when motivation peaks.
- Push: subscribe after first report ("get notified if someone finds/claims
  this dog") — contextual permission asks convert; page-load asks get blocked.
- Offline: read cache of already-seen reports; queue is out of scope v1
  (report creation requires connectivity for presigned upload).

## Images

Client-side pipeline before upload: orient via EXIF flag → draw to canvas →
export JPEG quality ~0.82 at 1600 px long edge + 320 px thumbnail →
presigned PUT both. Canvas re-encode strips all metadata (ADR-0003 privacy
note). Reject files >25 MB pre-processing with a friendly message.

## Map

MapLibre GL, OpenFreeMap vector tiles (no key). Fuzzed locations render as
~250 m radius circles, not exact pins. Fallback plan if MapLibre costs more
than 2 days of fight: Leaflet + raster OSM tiles (note tile-usage policy).

## i18n

PT + EN from M4 via a light solution (e.g. i18next). All strings
externalized from day one — retrofitting i18n is misery.
