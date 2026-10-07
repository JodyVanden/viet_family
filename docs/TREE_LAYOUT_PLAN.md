# Tree layout rework — Implementation Plan

Derived from `docs/TREE_LAYOUT_SPEC.md`. Task checklist lives in `docs/TREE_LAYOUT_TODO.md`.

## Context

All layout logic lives client-side in `app/javascript/controllers/tree_controller.js`
(no server round-trip, per spec §4.4). Five rules from the spec (R1–R5) map onto three
existing methods:

- **R1** (seniority order) → `unitChildren()` — drop the "childless siblings first" sort.
- **R2** (outward-facing spouses) → `placeAt()` — currently always blood-child-left,
  spouse-right; needs to pick a side.
- **R3** (linked families adjacent, linking child exempt from R1) → `rootUnits()` /
  `layoutUnit()` traversal order and `unitChildren()`'s ordering — the most structurally
  invasive change.
- **R4** (no bus crosses a foreign subtree) is the *acceptance test* for R3, not separate
  code — verified with a general invariant spec.
- **R5** (no other behavior changes) is guarded by keeping all existing system/request
  specs green throughout.

`this.orderIndex` (insertion order of `nodesValue`) already reflects birth order, because
`TreeController#show` loads people via `Person.order(:birth_date, :name)`. R1 is mostly
*removing* code, not adding it.

## Dependency graph (vertical slices)

```
T1 Seniority order (R1) ─► T2 Outward-facing spouses (R2) ─► T3 Family adjacency (R3)
                                                                       │
                                                                       ▼
                                                        T4 No-crossing invariant (R4, all families)
                                                                       │
                                                                       ▼
                                                        T5 Full regression + manual verify + docs
```

T2's spec is written against post-T1 ordering; T3 further reorders siblings (the R3
exemption), so it must land after T1/T2. T4 is a general acceptance check that only
makes sense once T3 exists. T5 closes the loop.

## Guardrails (from CLAUDE.md, unchanged)

- TDD mandatory: red → green → refactor, test(s) first, every task.
- Commit after each completed task — ask before running `git commit`.
- No new dependencies (JS test runner, npm packages) — ask first, per spec §8.
- `app/kinship/`, golden vectors, models, JSON export: untouched.

---

## T1 — Seniority-ordered siblings (R1)

**Description:** Remove the `hasKids`-first sort in `unitChildren()`; children of a
couple are ordered purely by `orderIndex` (birth date, then name — already the load
order). No other method changes.

**Test-first:** system spec on **Mai Thi Pham + Quoc Van Vu**'s children (Linh, Giang,
Trang, Huy, Phuc) — none of them marry into another rendered family, so this group is
unaffected by the later R3 exemption and gives a stable assertion: x-positions strictly
increase in seed birth-date order.

**Acceptance criteria:**
- [ ] `unitChildren()` no longer sorts by `hasKids`.
- [ ] New spec passes; it fails against the current code (red baseline confirmed before
  the fix).

**Verification:** `bundle exec rspec spec/system/family_tree_spec.rb`; full
`bundle exec rspec`; `bundle exec rubocop`.

**Files:** `app/javascript/controllers/tree_controller.js`,
`spec/system/family_tree_spec.rb`.

---

## T2 — Outward-facing spouse orientation (R2)

**Description:** `placeAt(a, b, centerX)` currently always places `b` to the right of
`a`. Add a side decision: for a couple where one side (`a` or `b`) has no parents in the
tree (married-in) and the other has siblings rendered alongside, put the married-in
spouse on the side facing away from the majority of those siblings — left if the blood
partner is the leftmost of their sibling row, right if rightmost, and the side with
fewer siblings when mid-row (per spec R2). Requires knowing each unit's position within
its sibling row at placement time, which `layoutUnit`/`unitChildren` already compute
(the children array is ordered; index 0 and last are the row edges).

**Test-first:** system spec using **Hung Van Tran + Lan Thi Pham**'s children (Suong,
Loc, Nam, Phong — order confirmed by T1): Suong is the row's leftmost blood sibling, so
her husband Khoi Van Dinh should sit to Suong's *left*; Phong is rightmost, so his wife
My Thi Vo should sit to Phong's *right*. Both assertions are independent of where Nam
ends up under T3, so this spec is stable across T3.

**Acceptance criteria:**
- [ ] Leftmost sibling's married-in spouse sits left of them.
- [ ] Rightmost sibling's married-in spouse sits right of them.
- [ ] Existing couple-panel rendering (`drawCoupleGroup`) still wraps the pair correctly
  regardless of which side the spouse is on (it already uses `min`/`max` of both
  positions, so this should need no change — confirm with a visual check).

**Verification:** same as T1, plus a manual look at `bin/dev` to confirm the couple
panel still frames both orientations correctly.

**Files:** `app/javascript/controllers/tree_controller.js`,
`spec/system/family_tree_spec.rb`.

---

## T3 — Family adjacency + linking-child edge placement (R3)

**Description:** The core structural change. When a marriage joins two people who each
have parents rendered in the tree (a "linked" couple — e.g. Nam Van Tran × Hoa Thi
Pham), lay the two family blocks out side by side and place the linking child at the
edge of their own sibling row nearest the in-law block, overriding strict R1 order for
that one child. Concretely:
- In `unitChildren()`, detect a child whose spouse also has parents in the tree; move
  that child to the front or back of the sibling array (nearest the side their in-law
  block will occupy) instead of their strict seniority slot.
- In `rootUnits()` / `layoutUnit()`, when recursing into a linked couple, lay out the
  in-law family's root unit immediately adjacent (same pass) rather than wherever it
  falls in iteration order, so the two blocks end up contiguous with no third family
  wedged between them.

**Test-first:** system spec asserting, for the seeded family:
- Nam Van Tran sits at the edge of Hung/Lan's sibling row (not seniority position 3 of 4).
- The Pham block (Dao Van Pham, Nga Thi Le, Hoa Thi Pham, Mai Thi Pham, and Mai's
  children) is horizontally contiguous with the Tran block — no other family's nodes sit
  between Nam/Hoa's couple and the rest of the Pham block.
- Dao Van Pham + Nga Thi Le's x-position sits within the horizontal span of their own
  children (Hoa, Mai) — their bus no longer reaches across the Tran subtree.

**Acceptance criteria:**
- [ ] All three assertions above pass.
- [ ] T1 and T2 specs (on unaffected sibling groups) still pass unchanged.
- [ ] Manual check in `bin/dev`: the row from the original screenshot (Suong/Khoi … Loc
  … Nam/Hoa … Phong/My … Mai) no longer has Nam's couple wedged between his
  own siblings, and the long cross-canvas line is gone.

**Verification:** full `bundle exec rspec`; `bundle exec rubocop`; manual browser check
(`bin/dev`, load the tree, visually compare against the original screenshot).

**Files:** `app/javascript/controllers/tree_controller.js`,
`spec/system/family_tree_spec.rb`.

> **Checkpoint** — this is the highest-risk task. Stop and confirm the rendered tree
> looks right in the browser before moving to T4.

---

## T4 — No-crossing invariant, whole family (R4)

**Description:** R4 is stated as the acceptance test for R3, generalized: write a spec
helper that, given all rendered families' computed bus/drop-line segments (read from the
DOM position data, same technique as T1–T3), asserts no family's horizontal bus or
vertical drop line crosses another family's bus or drop line, run across *every* family
in the seeded tree (not just the ones named in T3). This locks the invariant in for
future seed-data changes, not just today's specific fix.

**Test-first:** the general spec is expected to already pass after T3 for this seed
family (R4 is a consequence of R3); if it doesn't, that reveals a gap in T3's placement
logic to fix here.

**Acceptance criteria:**
- [ ] General no-crossing spec passes for the full seeded family.
- [ ] Spec is written so it would fail on the pre-T3 code (verify by temporarily
  checking it against `git stash` of T3, or by reasoning from the original bug —
  document which).

**Verification:** `bundle exec rspec spec/system/family_tree_spec.rb`; full suite.

**Files:** `spec/system/family_tree_spec.rb` (spec-only task; fix forward in
`tree_controller.js` only if the invariant fails).

---

## T5 — Full regression, manual verification, docs

**Description:** Close out the feature. No code changes expected beyond fixes surfaced
by regression.

**Acceptance criteria:**
- [ ] Full `bundle exec rspec` green (all pre-existing specs + new ones).
- [ ] `bundle exec rubocop` clean.
- [ ] Manual browser pass: load `bin/dev`, click through several people as viewpoint,
  confirm relabeling/highlighting/pan-zoom/couple panels are unaffected (R5).
- [ ] Update `docs/TREE_LAYOUT_SPEC.md` status from "Draft" to "Implemented".
- [ ] Note in `docs/SPEC.md`'s tree-visualization section (if it references layout
  details) is still accurate — update only if stale.

**Verification:** as above.

**Files:** `docs/TREE_LAYOUT_SPEC.md`, `docs/SPEC.md` (only if needed).
