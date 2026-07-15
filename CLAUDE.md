# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Stack

- Ruby on Rails 8.1 (PostgreSQL, Propshaft)
- Turbo + Stimulus (importmap, no Node build step for JS)
- Tailwind CSS (`tailwindcss-rails`)
- RSpec + FactoryBot for testing
- Rubocop (`rubocop-rails-omakase`) for linting

## Feature workflow

This project uses the **agent-skills** plugin (`agent-skills@addy-agent-skills`). Every non-trivial
feature must move through this sequence, using the plugin's slash commands in order:

1. `/spec` — write the spec: objectives, scope, boundaries, acceptance criteria.
2. `/plan` — break the spec into small, atomic, independently verifiable tasks.
3. `/build` — implement one task at a time, following **TDD (red-green-refactor)** for every task:
   write a failing test first, make it pass with the minimal change, then refactor.
4. `/review` — five-axis code review before anything is considered mergeable.
5. `/code-simplify` — simplify and clean up the implementation while preserving behavior.
6. `/ship` — final checks and deploy/release steps.

Do not skip steps and do not reorder them. Each task within `/build` must have its own test(s)
written before implementation code (TDD is mandatory, not optional, for every task — including bug
fixes and small changes).

## Documentation

- All generated documentation (specs, plans, ADRs, review notes, etc.) lives under `/docs`.
- Never write generated docs to the repo root or scattered elsewhere.
- After a task is completed and verified (tests passing), update the relevant docs in `/docs` to
  reflect the new state before moving to the next task. Do not mark a task "done" in a plan/doc
  without first confirming its tests actually pass.

## Git commits

- Work directly on `main` (no per-feature branches required).
- Commit after every completed task (spec, plan, each build task, review fixes, simplification
  pass, ship step) — not just at the end of a feature.
- Always ask for confirmation before running `git commit`. Never commit automatically.
- Keep commits atomic: one task's change per commit, with a message describing why.

## Project — viet_family

A private, family-shared **Vietnamese family tree**. Full specification: `docs/SPEC.md`.

Its defining feature is **perspective-based kinship terms**: the Vietnamese word for a relative
depends on *who is viewing* the tree (paternal vs. maternal side, seniority, gender). Selecting a
person as the viewpoint relabels every other person. Default dialect: **Southern Vietnamese**.

### Domain invariants (do not violate)

- **One source of truth for kinship.** All relationship and term logic lives in `app/kinship/`
  as pure Ruby POROs — no ActiveRecord, no Rails, no I/O. Controllers/views/services call into it;
  they never re-derive relationships or terms. Never scatter these rules across the app.
- **Golden vectors are ground truth.** `spec/fixtures/kinship_vectors.json` holds
  `{viewer, target} → expected term` cases. The engine must pass them; every kinship change or bug
  fix adds a case. A future mobile implementation must pass the *same* file. Never let the engine
  and the vectors disagree.
- **Seniority has one rule.** `Kinship.senior?(a, b)` compares `birth_date` when both siblings have
  reliable dates, else falls back to optional `birth_order`, else returns unknown. `birth_order` is
  a fallback signal, not an independent source of truth. This drives bác vs. chú/cô/cậu/dì.
- **The JSON export is a versioned contract** (`schema_version`), used for sharing now and as the
  future mobile app's data source. Bump the version and keep `Family::Exporter`/`Family::Importer`
  in sync on any format change. Don't couple the format to Rails internals.
- **Phase-2 boundaries.** Do not build without asking: auth/accounts/sharing/sync, multi-photo
  galleries or document attachments (Phase 1 is a single portrait per person), moving portrait
  storage off local disk, cloud deployment, or changing the default dialect / JSON schema shape.
- **Never** expose family data publicly or add analytics/third-party trackers.
