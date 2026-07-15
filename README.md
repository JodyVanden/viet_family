# viet_family

A private, family-shared **Vietnamese family tree**. Its defining feature is
**perspective-based kinship terms**: the Vietnamese word for a relative depends on
*who is viewing* the tree (paternal vs. maternal side, seniority, gender). Click a
person in the tree and every other person is relabelled from their point of view —
e.g. the same man is *Ba vợ* (father-in-law) to the husband but *Ông ngoại*
(maternal grandfather) to the son.

Full specification: [`docs/SPEC.md`](docs/SPEC.md) · plan & tasks:
[`docs/plan.md`](docs/plan.md), [`docs/todo.md`](docs/todo.md).

## Stack

- Ruby on Rails 8.1 (PostgreSQL, Propshaft)
- Hotwire (Turbo + Stimulus) via importmap — no Node build step
- Tailwind CSS
- RSpec + FactoryBot; Capybara + Selenium (headless Chrome) for system tests

The kinship rules live in a **pure, framework-free** Ruby engine under
`app/kinship/` and are pinned by language-agnostic golden vectors
(`spec/fixtures/kinship_vectors.json`).

## Setup

```bash
bin/setup            # install gems and prepare the database
bin/rails db:seed    # load the sample family (incl. the Ba vợ / Ông ngoại case)
bin/dev              # start the app + Tailwind watch at http://localhost:3000
```

Requires a local PostgreSQL and (for system tests) Google Chrome + chromedriver.

## Testing

```bash
bundle exec rspec              # full suite
bundle exec rspec spec/kinship # just the kinship engine (golden vectors)
bin/rubocop                    # lint (rubocop-rails-omakase)
```

## Sharing the tree (JSON export/import)

The whole family exports to a versioned, self-contained JSON file (portraits
embedded as base64) — the sharing mechanism and the future mobile app's data
contract:

```bash
bin/rails family:export FILE=family.json
bin/rails family:import FILE=family.json
```

## Kinship dialect

Terms default to **Southern Vietnamese** (Ba/Má). The engine is dialect-parameterized;
see `docs/SPEC.md §2` for the full term table and the Southern rule that resolves
regional overlaps (e.g. Bác = father's older brother only).
