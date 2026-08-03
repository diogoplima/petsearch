# ADR-0001: PWA over native mobile apps

**Status:** accepted

## Context
The app must work on Android and iPhone. Native apps mean two codebases (or
React Native/Flutter), app-store review cycles, and install friction for a
use-once-in-a-crisis product.

## Decision
Build an installable PWA (React + Vite + Workbox). No native apps in v1.

## Consequences
- One codebase, instant deploys, shareable URLs (critical: "found a dog?
  report it here" links in Facebook groups).
- iOS limitation: web push only works when the PWA is added to the home
  screen — so email is the guaranteed notification channel (see ADR and
  architecture notification flow).
- If store presence ever matters, Capacitor can wrap the existing PWA.
