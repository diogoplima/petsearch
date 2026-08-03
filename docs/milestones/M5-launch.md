# M5 — Launch (Barcelos / Braga)

**Goal:** 10 real reports from people who aren't you. This milestone is
mostly not code — treat outreach tasks with the same seriousness as
endpoints, or the previous four milestones were for nothing (ADR-0009's
launch-local strategy lives or dies here).

## Steps

1. **README as a landing page**: what it is (one sentence), live URL, 3–4
   phone screenshots, architecture diagram, "why these choices" linking the
   ADRs, quickstart (`make dev`), CONTRIBUTING.md, code of conduct.
   Remember its dual audience: dog owners AND hiring managers.
2. **Demo video** (≤90 s screen recording, phone frame): file a sighting →
   candidate appears → confirm → reveal. Embed in README, reuse everywhere.
3. **GitHub housekeeping**: issue templates (bug / feature), labels,
   `good-first-issue` on 3–5 genuinely small items, enable Discussions,
   GitHub Sponsors / a donation link (hosting transparency: "runs on ~€5/mo").
4. **Seed content honestly**: a handful of real regional reports sourced
   from public lost-pet posts *with permission of the posters* — an empty
   map kills first-visit trust, but fabricated dogs would be worse. Mark
   nothing as real that isn't.
5. **Outreach list** (do the unscalable thing): local Facebook lost-pet
   groups (ask admins to pin), veterinary clinics and pet shops (A5 flyer
   with QR code), the municipal kennel / canil, junta de freguesia notice
   boards, local subreddit/forums. Track contacts in a simple sheet.
6. **Feedback channel**: a visible "feedback" link (mailto or GitHub
   Discussions) in the app footer. First-user friction reports are gold;
   make them one tap away.
7. **Measure minimally**: a weekly SQL query is enough — reports created,
   users, matches suggested/confirmed, and the number that matters:
   **reunions** (confirmed matches on missing dogs later marked resolved).
   Write it as `docs/metrics.sql`.
8. **Post-launch cadence**: fix friction weekly; resist feature requests
   that aren't blocking reports or matches (the roadmap's "deliberately not
   scheduled" list is your shield).

## Alternatives worth knowing

- **Seeding**: permissioned real reports (recommended) vs launching empty
  (honest but cold — acceptable if outreach lands day-one posts) vs demo
  data flagged as demo (clear but makes the app feel like a mockup).
- **Announce dev-publicly?** Writing a launch/architecture blog post and
  posting to r/golang / Hacker News is high-value for the portfolio goal —
  but do it *after* local users exist, so the post has a "real users"
  paragraph. A launch post about zero-user software is just a spec.

## Definition of Done

- [ ] 10 reports from strangers
- [ ] at least one piece of user feedback received and acted on
- [ ] README + video make the project fully legible to a hiring manager in
      under 3 minutes
