# Tree layout rework — Task checklist

Full detail in `docs/TREE_LAYOUT_PLAN.md`. One `/build` task at a time, TDD, commit after each.

- [x] **T1** — Seniority-ordered siblings (R1): drop "childless first" sort in `unitChildren()`.
- [x] **T2** — Outward-facing spouse orientation (R2): married-in spouse sits away from siblings.
- [x] **T3** — Family adjacency + linking-child edge placement (R3). ⚠️ highest-risk task —
      checkpoint with manual browser verification before continuing.
- [x] **T4** — No-crossing invariant (R4), general spec across the whole seeded family.
- [x] **T5** — Full regression, manual verification, docs status update to "Implemented".
