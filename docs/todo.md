# viet_family — Task List (Phase 1)

Ordered, atomic, TDD tasks from `docs/plan.md`. Each: write failing test(s) first, implement
minimally, refactor, verify, then commit (ask first). Check off only after tests pass.

## P0 — Foundation
- [x] **T0.1** Scaffold Rails 8.1 app (PostgreSQL, Propshaft, importmap, Tailwind) + RSpec, FactoryBot, rubocop-rails-omakase; smoke spec green
- [x] **C0** Checkpoint: `bin/dev` boots, `bundle exec rspec` + `bin/rubocop` green — commit

## P1 — Kinship engine (pure Ruby, no DB) — highest risk
- [x] **T1.1** Fixture family + `kinship_vectors.json` + golden-vector RSpec harness (red baseline)
- [ ] **T1.2** `Kinship::Graph` — siblings/children derivation, spouse edges, shortest-path
- [ ] **T1.3** `Kinship.senior?` — birth_date → birth_order → unknown precedence
- [ ] **T1.4** Terms: grandparents & parents (Ông/Bà nội·ngoại, Ba/Má)
- [ ] **T1.5** Terms: siblings (anh/chị/em via senior?)
- [ ] **T1.6** Terms: parent's siblings (bác/chú/cô/cậu/dì + thím/mợ/dượng; all father's sisters = Cô)
- [ ] **T1.7** Terms: spouse & parents-in-law (chồng/vợ, Ba/Má vợ·chồng) — driving perspective case
- [ ] **T1.8** Terms: descendants, cousins, unknown fallback (con/cháu, họ, plain-name)
- [ ] **T1.9** Harden: full vector suite green, ~100% coverage, engine framework-free
- [ ] **C1** Checkpoint: golden suite green, coverage met, no Rails deps — commit

## P2 — Persistence & graph adapter
- [ ] **T2.1** `Person` model + migration + factory + validations
- [ ] **T2.2** `Relationship` self-join (parent/spouse) + migration + validations (no cycles/dupes)
- [ ] **T2.3** `Note` model + factory
- [ ] **T2.4** Portrait via Active Storage + content-type/size validation
- [ ] **T2.5** Graph adapter: AR records → `Kinship::Graph` (reuse engine); end-to-end term spec
- [ ] **T2.6** Seeds: canonical sample family incl. driving case
- [ ] **C2** Checkpoint: seeded DB computes correct term via adapter+engine — commit

## P3 — Versioned JSON contract
- [ ] **T3.1** `Family::Exporter` → versioned JSON (decide portrait encoding)
- [ ] **T3.2** `Family::Importer` ← JSON + version validation + round-trip spec
- [ ] **T3.3** Rake tasks `family:export` / `family:import`
- [ ] **C3** Checkpoint: round-trip identical, terms unchanged — commit

## P4 — UI (Hotwire, vertical slices)
- [ ] **T4.1** People index + show (portrait/placeholder) + system test
- [ ] **T4.2** New/edit person (Turbo form) + portrait upload + system test
- [ ] **T4.3** Relationships UI (link parent/child/spouse) + system test
- [ ] **T4.4** Notes CRUD per person (Turbo Streams) + system test
- [ ] **T4.5** Tree visualization (importmap tree lib + Stimulus, portraits, pan/zoom) + system test
- [ ] **T4.6** Viewpoint selection (headline) — relabel all nodes; assert Ba vợ vs Ông ngoại + system test
- [ ] **C4** Checkpoint: full create→link→portrait→tree→viewpoint flow works — commit

## P5 — Ship
- [ ] **T5.1** README/quickstart, docs sync, /review, /code-simplify, final rubocop, demo seed
- [ ] **C5** Checkpoint: Phase-1 acceptance met — commit
