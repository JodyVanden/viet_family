# Tree layout rework — Specification

**Status:** Implemented (T1–T5 complete, 2026-07-19)
**Date:** 2026-07-19
**Related:** `docs/SPEC.md` §Tree visualization, `app/javascript/controllers/tree_controller.js`

## 1. Objective

Fix the confusing placement of couples and siblings in the family tree so that a family
member can read any generation row left-to-right and immediately tell who is a blood
sibling, who married in, and which parents a child-bus belongs to.

**The problem (observed with the seed family):**

1. Siblings are re-ordered by a "childless first" heuristic, so a person can end up
   mid-row with siblings on both sides of their couple.
2. A couple is always drawn blood-child-left / spouse-right, so the married-in spouse
   often sits *between* the blood child and their next sibling and reads as a sibling.
3. When both spouses have parents in the tree, whichever family happens to be laid out
   first claims the couple. The other family's children-bus then stretches across the
   whole canvas (Dao Van Pham + Nga Thi Le's bus crossing the entire Tran block).

**Success looks like:** for the seed family, every sibling group reads in seniority
order, no married-in spouse interrupts a sibling run except where geometrically
unavoidable, and no family's children-bus crosses another family's subtree.

**Non-goal:** solving the general planarity problem. Marriage-linked family graphs are
not planar in general; this spec adopts the conventions that make real family shapes
(like ours) render cleanly. A ghost-card fallback for shapes adjacency cannot untangle
(see §8 of the research below) is **deferred to a later spec**.

## 2. Prior-art research (why these rules)

Surveyed 2026-07-19. Every mature open-source renderer avoids the cross-family problem
structurally rather than solving it geometrically:

- **[donatso/family-chart](https://github.com/donatso/family-chart)**
  (`src/layout/calculate-tree.ts`): hourglass centered on one person; spouses are not
  tree nodes — they are injected next to their partner after layout, and **in-law
  ancestors are simply not rendered** until you re-center on the spouse. Duplicate
  appearances are handled by rendering the person twice with a toggle.
- **[ErikGartner/dTree](https://github.com/ErikGartner/dTree)** (`src/dtree.js`):
  inserts a hidden *marriage node* between person and spouse; children hang off the
  marriage node; spouses get `noParent: true` — the data model cannot draw a spouse's
  parents at all.
- **[daveagp/family-tree](https://github.com/daveagp/family-tree)**
  ([write-up](https://daveagp.wordpress.com/2018/04/22/family-tree-visualizer/)):
  union nodes, whole family visible, strict birth order — and admits the cost: "very
  long horizontal edges leading to ancestors of the root" (exactly our bug).
- **[Reingold-Tilford adaptation](https://tbt.qkation.com/posts/draw-tree-using-reingold-tilford-algorithm/)**:
  couples as composite nodes; explicitly cannot render siblings' spouses' families.
- **Graphviz-based tools** ([familytreemaker](https://github.com/adrienverge/familytreemaker),
  Gramps graph view): union nodes + Sugiyama layered layout; renders everything but
  accepts crossings and gives up sibling-order control.

**Decision (2026-07-19):** keep our "whole family always visible" design (rules out the
hourglass/hide-in-laws approach) and adopt the ordering/orientation/adjacency
conventions below — the daveagp direction, borrowing couple conventions from
family-chart and dTree. Ghost cards deferred.

## 3. Layout rules (the requirements)

- **R1 — Seniority order.** Children of a couple are laid out oldest → youngest,
  left → right, using the same seniority rule as the kinship engine
  (`birth_date` when reliable, else `birth_order`). The "childless siblings first"
  sort in `unitChildren` is removed.
- **R2 — Outward-facing spouses.** A married-in spouse (no parents in the tree) is
  placed on the side of their partner facing *away* from the majority of the partner's
  blood siblings: leftmost sibling → spouse on the left; rightmost → spouse on the
  right; mid-row → the side with fewer blood siblings (a mid-row couple cannot avoid
  sitting next to some sibling; the couple panel still marks the pair).
- **R3 — Linked families are adjacent.** When a marriage joins two families that both
  have parents rendered in the tree, the two family blocks are laid out side by side
  and the linking couple sits at the shared edge. The linking child is **exempt from
  R1** — they move to the edge of their sibling run nearest the in-law family. The
  in-law family block is placed on that same side.
- **R4 — A children-bus never spans a foreign subtree.** Consequence of R3, stated as
  its own invariant because it is the acceptance test: the horizontal bus connecting a
  couple to its children must not cross another couple's vertical drop lines or bus.
  (Holds for the seed family; the general case is out of scope per §1.)
- **R5 — Everything else is unchanged.** Whole family always visible; click-to-relabel,
  lineage highlight, couple panels, pan/zoom, fit-to-view, kinship terms: no behavior
  change. No changes under `app/kinship/`, no schema or JSON-export changes.

## 4. Assumptions

1. Sibling seniority mirrors `Kinship.senior?` semantics; when both signals are missing
   the current insertion order is kept (stable sort).
2. R3's birth-order exemption for the linking child is an accepted trade-off
   (cross-family adjacency matters more than strict order for that one person).
3. The seed family has no remarriages; multi-spouse layout keeps its current behavior
   and is out of scope (ask before changing).
4. Layout stays fully client-side in the Stimulus controller. The pure layout logic may
   be extracted to a framework-free module under `app/javascript/tree/` for testability,
   served via importmap — no Node build step is introduced.
5. No new JS test runner is added (would be a new dependency → ask first). TDD happens
   through Capybara system specs asserting rendered node positions (see §7).

## 5. Commands

```
Dev server:  bin/dev
Tests:       bundle exec rspec
One spec:    bundle exec rspec spec/system/family_tree_spec.rb
Lint:        bundle exec rubocop
Seed:        bin/rails db:seed
```

## 6. Project structure (files this touches)

```
app/javascript/controllers/tree_controller.js  → layout algorithm (main change)
app/javascript/tree/                           → (new, optional) extracted pure layout module
spec/system/family_tree_spec.rb                → layout acceptance specs
docs/TREE_LAYOUT_SPEC.md                       → this spec
docs/plan.md                                   → task breakdown (via /plan)
```

Not touched: `app/kinship/`, `app/services/family/` (exporter/importer), models,
controllers, `spec/fixtures/kinship_vectors.json`.

## 7. Testing strategy

System specs (Capybara + driver JS) are the TDD vehicle. Each layout rule gets a spec
that reads node positions from the DOM (`[data-node-id]` cards' `left`/`top` styles)
against the seeded family and asserts ordering/adjacency invariants, e.g.:

- R1: the x-positions of Hung/Lan's children run Suong < Loc < Nam < Phong —
  minus the R3 exemption, which moves the linking child to the shared edge.
- R2: a leftmost sibling's spouse sits left of them; rightmost's sits right.
- R3: Nam + Hoa are horizontally adjacent to the Pham block; Dao/Nga sit
  directly above their own children's span.
- R4: computed bus segments do not intersect drop lines of other families (helper
  assertion over the same position data).

Red-green-refactor per task: write the failing system spec first, implement the minimal
layout change, refactor. Existing system/request specs must stay green throughout.

## 8. Boundaries

- **Always:** keep every person visible on the canvas; keep sibling seniority and the
  kinship engine consistent (one seniority rule); run `bundle exec rspec` before any
  commit; keep layout logic pure (no server round-trips).
- **Ask first:** adding a JS test runner or any new dependency; changing multi-spouse
  behavior; any data-model or seed change beyond what layout needs; ghost/duplicate
  cards (deferred scope).
- **Never:** touch `app/kinship/` or the golden vectors for this feature; hide or
  filter people as a layout strategy; change the JSON export schema; add third-party
  services.
