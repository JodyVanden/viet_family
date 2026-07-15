# viet_family — Implementation Plan (Phase 1)

Derived from `docs/SPEC.md`. Task checklist lives in `docs/todo.md`.

## Context
Greenfield Rails 8.1 app for a private Vietnamese family tree. The defining, highest-risk
feature is the **perspective-based kinship engine** (Vietnamese terms depend on who is
viewing). We front-load that engine as pure Ruby — testable with zero database — then layer
persistence, the versioned JSON contract, and the Hotwire UI on top.

## Guardrails (from CLAUDE.md)
- **TDD is mandatory for every task**: red → green → refactor. Test(s) first, always.
- Work on `main`. **Commit after each completed task** (ask before committing). Atomic commits.
- All generated docs under `/docs`. Update docs after a task before moving on.
- One source of truth for kinship (`app/kinship/`, pure Ruby). Golden vectors are ground truth.

## Dependency graph (vertical slices, one complete path per task)
```
P0 Foundation ─► P1 Kinship engine ─► P2 Persistence+adapter ─► P3 JSON contract ─► P4 UI ─► P5 Ship
                     (pure Ruby,          (AR models →              (versioned          (Hotwire,
                      no DB, golden        engine graph adapter)     export/import)       tree, viewpoint)
                      vectors)
```
- **P1 depends only on P0** (RSpec harness). It needs no DB — it runs on plain-Ruby fixtures.
- **P2 reuses P1** via a graph adapter (AR records → `Kinship::Graph`). No term logic re-implemented.
- **P3 depends on P2** (serializes the same models); its round-trip is validated with the engine.
- **P4 depends on P2/P3** and surfaces the engine; the viewpoint feature is the headline slice.

---

## P0 — Foundation
**T0.1 Scaffold Rails app + test/lint tooling.**
`rails new . -d postgresql -a propshaft -j importmap -c tailwind --skip-test`; add
`rspec-rails`, `factory_bot_rails`, `rubocop-rails-omakase`; configure RSpec + FactoryBot.
- *Test-first*: a trivial smoke spec that must go green.
- *Acceptance*: `bin/dev` boots at :3000; `bundle exec rspec` green; `bin/rubocop` clean; DB created.
- *Verify*: `bin/setup && bin/rails db:prepare && bundle exec rspec && bin/rubocop`.

> **Checkpoint C0** — app boots, specs + lint run green. Commit.

---

## P1 — Kinship engine (pure Ruby, no DB) — highest risk, do first
All tasks: pure `app/kinship/` POROs, **no ActiveRecord/Rails/I/O**. Each term slice adds
cases to `spec/fixtures/kinship_vectors.json` and turns them green.

**T1.1 Fixture family + golden-vector harness.** Define the plain-Ruby person shape and a
canonical sample family covering every branch (incl. the *Ba vợ / Ông ngoại* case). Create
`kinship_vectors.json` with initial `{viewer, target} → term` cases and an RSpec harness that
iterates it (red baseline — no engine yet).
- *Acceptance*: harness loads fixture + vectors and runs (failing until engine exists).

**T1.2 `Kinship::Graph`.** Build graph from fixture; derive `siblings`/`children` from parent
edges; spouse edges; shortest relationship path between two people.
- *Acceptance*: unit specs for sibling/child derivation and path-finding on the fixture.

**T1.3 `Kinship.senior?(a, b)`.** Precedence: reliable `birth_date`s → compare; else
`birth_order`; else *unknown*.
- *Acceptance*: specs for date-based, order-fallback, and unknown cases.

**T1.4 Terms: grandparents & parents** — Ông/Bà nội·ngoại, Ba/Má. Vectors green.
**T1.5 Terms: siblings** — anh/chị/em via `senior?`. Vectors green.
**T1.6 Terms: parent's siblings** — bác/chú/cô/cậu/dì + spouses thím/mợ/dượng; side + `senior?`;
**all father's sisters = Cô**. Vectors green.
**T1.7 Terms: spouse & parents-in-law** — chồng/vợ, Ba/Má vợ·chồng. Includes the driving
perspective case computed from two different viewpoints. Vectors green.
**T1.8 Terms: descendants, cousins, fallback** — con/cháu, anh/chị/em họ; graceful plain-name
fallback for unknown/unreachable. Vectors green.

**T1.9 Harden.** Full golden suite green; **near-100% coverage on `app/kinship/`**; assert the
engine has zero Rails constants.
- *Verify*: `bundle exec rspec spec/kinship` all green; coverage report; grep confirms no `ActiveRecord`/`Rails` in `app/kinship/`.

> **Checkpoint C1** — entire golden-vector suite green, coverage target met, engine framework-free. Commit.

---

## P2 — Persistence & graph adapter
**T2.1 `Person`** model + migration (name, gender, birth_date, death_date, birth_order) + factory + validations.
**T2.2 `Relationship`** self-join (kind: parent/spouse) + migration + validations (distinct
endpoints, valid kind, no duplicate edges, no parent cycles).
**T2.3 `Note`** belongs_to person (text) + factory.
**T2.4 Portrait** via Active Storage (`has_one_attached :portrait`) + content-type/size validation.
**T2.5 Graph adapter** — build `Kinship::Graph` from AR `Person`/`Relationship`; **reuse the
engine**, no term logic here. End-to-end spec: DB records → correct term.
**T2.6 Seeds** — canonical sample family mirroring the fixture, incl. the driving case.
- *Verify each*: model/adapter specs green; `bin/rails db:seed` then `bin/rails runner` prints the correct term for the driving case.

> **Checkpoint C2** — seeded DB computes correct kinship via adapter+engine. Commit.

---

## P3 — Versioned JSON contract
**T3.1 `Family::Exporter`** → versioned JSON (`schema_version`, people, relationships, notes,
dialect, portrait refs). Decide portrait encoding (base64 vs side-car) here.
**T3.2 `Family::Importer`** ← JSON; validate version, rebuild graph; **round-trip spec**
(export → import → identical graph; engine terms identical pre/post).
**T3.3 Rake tasks** `family:export` / `family:import`.
- *Verify*: round-trip spec green; `bin/rails family:export` then `family:import` into a clean DB reproduces the tree.

> **Checkpoint C3** — round-trip identical; terms unchanged across it. Commit.

---

## P4 — UI (Hotwire, vertical slices) — each task is a full user path with a system test
**T4.1 People index + show** — Tailwind, portrait/placeholder.
**T4.2 New/edit person** — Turbo form incl. portrait upload.
**T4.3 Relationships UI** — link parent/child/spouse via Turbo.
**T4.4 Notes CRUD** per person via Turbo Streams.
**T4.5 Tree visualization** — importmap-pin the tree lib; **one Stimulus controller** renders the
DAG (couples + multiple parents) with portraits, pan/zoom.
**T4.6 Viewpoint selection (headline)** — click a node → server recomputes and relabels every
node with the correct Vietnamese term via the engine. **System test asserts the same person shows
*Ba vợ* from one viewpoint and *Ông ngoại* from another.**
- *Verify each*: Capybara system test drives the path in a real browser.

> **Checkpoint C4** — create people → link → set portraits → open tree → switch viewpoint → labels update correctly. Commit.

---

## P5 — Ship (Phase-1 close-out)
**T5.1** README/quickstart, docs sync, run `/review` then `/code-simplify`, final `bin/rubocop`,
demo seed. (Deployment via Kamal deferred to Phase 2.)

> **Checkpoint C5** — Phase-1 acceptance met end-to-end. Commit.

---

## Open items to resolve during build (non-blocking)
- **Tree library** pinned via importmap (leaning `d3-hierarchy` for ESM/importmap friendliness).
- **Portrait handling in JSON export** — base64-embed vs. side-car files (decide in T3.1).

## Out of scope (Phase 2+) — do not build without asking
Auth/accounts/sharing/sync, multi-photo galleries, off-disk portrait storage, cloud deploy,
native mobile app, changing default dialect or JSON schema shape.
