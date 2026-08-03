---
name: frontend-conventions
description: Conventions for all frontend work in web/ — React components, the PWA service worker, forms, maps, image handling, push notifications, or styling. Use whenever writing or modifying anything under web/, and whenever a task mentions screens, UI, camera, photos, geolocation, the map, offline behavior, or install prompts.
---

# Frontend conventions (web/)

React 18 + TS + Vite PWA. The design target is one-handed phone use by a
stressed person standing next to a dog. Every screen decision defers to
docs/services/web.md.

## Non-negotiables

- The report flow must complete in under 90 seconds on a mid-range phone.
  Any addition to that flow needs justification against this budget.
- Only photo + location pin are required fields; everything else optional.
- Images: resize + re-encode on canvas BEFORE upload (1600 px main, 320 px
  thumb, JPEG ~0.82). This also strips EXIF/GPS — a privacy requirement
  (ADR-0003), not an optimization. Never upload original files.
- Locations shown publicly are fuzzed: render as ~250 m circles, never
  precise pins. Exact pins appear only in confirmed-match views.
- Report drafts persist to IndexedDB so the magic-link login roundtrip
  can't lose a half-completed report.

## Patterns

- Server state via TanStack Query only — no server data in useState/context.
  Query keys: `['reports', filters]`, `['report', id]`, `['matches']`.
- API layer: one typed client module; responses validated with Zod schemas
  shared across screens. 401 → redirect to auth, preserving the draft.
- Forms: controlled, Zod-validated, errors inline next to fields.
- Map: MapLibre GL + OpenFreeMap; lazy-load the map bundle (it's the
  heaviest dep) — the list view must render without it.
- i18n: no hardcoded user-facing strings; everything through the i18n layer
  from the first component (PT + EN).
- Permission asks are contextual: geolocation when entering the location
  step; push after first report submission; never on page load.
- iOS: after first submission, show the add-to-home-screen sheet (push only
  works installed).

## Service worker

- vite-plugin-pwa / Workbox: precache shell; network-first `/v1/*`;
  cache-first, size-bounded for tiles and R2 thumbnails.
- Never cache authenticated responses containing private data.

## Testing

- Vitest for logic (image pipeline, validation, scoring display).
- The Playwright e2e covering report → suggest → confirm → reveal is
  sacred: keep it green, extend it when the flow changes.
