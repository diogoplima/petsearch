# ADR-0012: Species-ready schema, dogs-only launch

**Status:** accepted

## Context
Product and branding launch dogs-only for focus. Success predictably invites
"what about my cat?" — and renaming/restructuring post-launch is expensive,
while a dormant column is one line now.

## Decision
`reports.species text not null default 'dog'`; matching filters on species
equality. UI, copy, and launch remain dogs-only. Expanding later = allowing
new values + UI work, not a migration.

## Consequences
- Expansion becomes a product decision, not a schema project.
- Attribute fields (breed, size) are dog-shaped; other species may need
  additions later — accepted, additive.
- Rejected: species enum (needlessly rigid) and multi-species launch
  (dilutes the launch focus that ADR-0009's local strategy depends on).
