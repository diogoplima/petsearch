# ADR-0003: Browser geolocation + manual pin over EXIF metadata

**Status:** accepted

## Context
The original idea was to read photo GPS metadata. In practice EXIF is
unreliable: messaging apps strip it, mobile OSes strip location on share for
privacy, and gallery-picked photos in browsers often arrive without it.
For *missing* reports it's also semantically wrong — the photo is from home,
weeks ago; the relevant location is "last seen area".

## Decision
Capture `navigator.geolocation` at report time, always show a draggable map
pin for correction, never read EXIF. Client-side canvas re-encoding strips
all metadata from uploaded photos as a side effect (privacy win).

## Consequences
- Location quality no longer depends on photo provenance.
- Requires location permission UX; the pin fallback covers denials.
