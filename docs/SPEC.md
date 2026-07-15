# viet_family — Specification

## 1. Objective

A **private, family-shared Vietnamese family tree** application.

The distinguishing feature is **perspective-based kinship terms**: Vietnamese kinship
terminology is relational — the word used for a relative depends on *who is speaking*.
It encodes paternal vs. maternal side, seniority/age rank, and gender. The same person
therefore has different names depending on which person you are "viewing the tree from."

**Example (the driving use case):** The user's children call his wife's father
*Ông ngoại* (maternal grandfather), while the user himself calls the same man *Bố vợ*
(father-in-law). One person, two labels, chosen by viewpoint.

### Target users
The builder's own family. **Phase 1 has no authentication** — the goal is a working
family tree with correct kinship computation, run locally. Multi-user login/sharing and a
native mobile app are **deferred to Phase 2+** (see §9). Because the future mobile app may
be **standalone/local-first**, the JSON export format and the kinship rules are treated as
portable, first-class contracts from day one (see §2, §8).

### Scope — Phase 1 (this spec)
- **People & relationships**: add/edit people (name, gender, birth/death dates, birth
  order among siblings) and link parents, children, and spouses.
- **Perspective-based kinship terms**: select any person as the viewpoint; every other
  person is labeled with the correct Vietnamese kinship term relative to that viewpoint.
  Default dialect: **Southern Vietnamese** (Ba/Má).
- **Portrait photo per person**: upload/set a single portrait image per person, shown on
  the tree node and the person detail page (graceful placeholder when absent).
- **Tree visualization**: interactive, pan/zoom family tree that handles couples and
  multiple parents; clicking a node sets the viewpoint. Nodes display the portrait.
- **Stories & notes**: long-form biography/notes per person.
- **JSON export / import**: export the whole family to a versioned JSON file and import it
  back. This is the Phase-1 sharing mechanism and the future mobile app's data contract.

### Out of scope (Phase 2+, do NOT build now)
- Authentication, accounts, invitations, sharing/permissions, multi-editor sync.
- Multi-photo galleries and document/media attachments (Phase 1 = *single* portrait each).
- The native mobile app itself (we only lock its data/rules contracts now).
- Public/cloud deployment (build local-first; direction noted in §9).

---

## 2. The kinship engine (the heart of the project)

The highest-value, highest-risk component. It is a **pure, framework-free Ruby module**
(`app/kinship/`, plain POROs — no ActiveRecord, no controllers), so it can be unit tested
exhaustively and reimplemented on other platforms against shared vectors.

### Data model (structured to make terms computable)
Each person carries the attributes a term depends on:
- `gender` (male / female / unknown)
- `birth_date` / `death_date` (relative-age comparisons and display)
- `birth_order` — **optional** ordinal rank among siblings; the *fallback* seniority
  signal (see below), not an independent source of truth
- `portrait` — optional attached image (display only; **not** used by term computation)
- Edges: `parents` (mother/father) and `spouses`, from which `children` and `siblings`
  are derived. The graph is a DAG (two parents per person), **not** a simple tree.

#### Sibling seniority (bác vs. chú/cô/cậu/dì) — single precedence rule
The seniority split for aunts/uncles compares **the viewer's parent to that parent's
sibling** (bác = *older* sibling of a parent; chú/cô/cậu/dì = *younger*) — people one or
two generations up, whose exact birth dates are often unknown. To avoid two fields that
can silently disagree, seniority is computed by one helper, `Kinship.senior?(a, b)`:

1. If **both** siblings have reliable `birth_date`s → compare dates.
2. Otherwise → fall back to explicit `birth_order`.
3. If neither is available → seniority is *unknown*; the engine returns a
   generation-appropriate neutral fallback rather than guessing.

`birth_order` therefore exists to capture ordinal knowledge families *do* have ("Ba was
the second son, Chú Tư the fourth") when dates are missing. When both dates exist,
`birth_order` is derivable — the UI may auto-suggest it and flag a stored value that
disagrees with the dates.

### Term computation
`Kinship.term(viewer:, target:, graph:, dialect:) => Term` walks the shortest
relationship path from `viewer` to `target` and maps it to a Vietnamese term using:
1. **Side** — paternal (nội) vs. maternal (ngoại), and in-law (…vợ / …chồng) vs. blood.
2. **Generation** — grandparent / parent / same / child / grandchild.
3. **Seniority** — whether the linking relative is older or younger than the viewer's
   own parent (bác = older sibling of a parent; chú/cô/cậu/dì = younger), and, within a
   generation, birth order / relative age (anh/chị = older, em = younger).
4. **Gender** of the target (and sometimes of the linking relative).

Unknown/unreachable relationships return a graceful fallback (the person's plain name),
never an error.

### Portability contract: golden vectors
Because a future standalone mobile app must compute terms **on-device** (its own language),
the rules are pinned by a **language-agnostic golden test-vector file**
(`spec/fixtures/kinship_vectors.json`): a list of `{viewer, target} → expected term` cases
over a fixed sample family. The Ruby engine must pass it now; any later implementation must
pass the *same* file. This is how the two implementations are prevented from drifting.

### Reference term set (Southern dialect default)
| Relationship to viewer | Term |
|---|---|
| Paternal grandfather / grandmother | Ông nội / Bà nội |
| Maternal grandfather / grandmother | Ông ngoại / Bà ngoại |
| Father / Mother | Ba / Má |
| Father's older sibling / their spouse | Bác |
| Father's younger brother / his wife | Chú / Thím |
| Father's sister (any age) / her husband | Cô / Dượng |
| Mother's older sibling / their spouse | Bác |
| Mother's brother / his wife | Cậu / Mợ |
| Mother's younger sister / her husband | Dì / Dượng |
| Older brother / older sister | Anh / Chị |
| Younger sibling | Em (em trai / em gái) |
| Husband / Wife | Chồng / Vợ |
| Father-/mother-in-law (spouse's parents) | Ba vợ·chồng / Má vợ·chồng |
| Son / Daughter | Con (con trai / con gái) |
| Grandchild / niece·nephew | Cháu |
| Cousin (extended, by age) | Anh/Chị/Em họ |

**Known complexity handled deliberately:** terms are regional; the engine takes a
`dialect` parameter, defaulting to Southern. Per project decision, **all father's sisters
are Cô regardless of age** (no older-sister → Bác distinction on the paternal-female
branch); seniority still governs bác vs. chú on the paternal-male branch and cậu/dì.

---

## 3. Tech stack (chosen)

Verified locally: Ruby 3.4.7, Rails 8.1.3, PostgreSQL 14.23 (running), Node 26 present.
Authoritative stack is defined in `CLAUDE.md`; this section must stay consistent with it.

- **Framework:** **Ruby on Rails 8.1 + Hotwire (Turbo + Stimulus)** — the builder's most
  familiar stack; ideal for server-rendered CRUD, forms, and portrait uploads with minimal
  custom JS.
- **Asset/JS pipeline:** **Propshaft** + **importmap** (no Node build step). Any JS library
  (e.g. the tree lib) is pinned via `bin/importmap pin`.
- **Styling:** **Tailwind CSS** via `tailwindcss-rails`.
- **Domain logic:** pure Ruby POROs in `app/kinship/` — no Rails dependencies — so kinship
  rules stay testable and portable to a future mobile app.
- **Data:** ActiveRecord with **PostgreSQL**. `Person`, `Relationship` (self-referential
  join: parent/spouse), `Note`.
- **Portraits:** **Active Storage**, local disk service in Phase 1 (`storage/`).
- **Tree visualization:** one **Stimulus controller** wrapping an importmap-pinned JS tree
  library (`relatives-tree` or d3-hierarchy — *open item, pick during build*); everything
  else is server-rendered HTML via Turbo Frames/Streams.
- **JSON export/import:** `Family::Exporter` / `Family::Importer` services producing/reading
  the versioned schema (§8).
- **Testing:** **RSpec + FactoryBot** — table-driven kinship specs driven by the golden
  vectors; system tests for the UI.
- **Lint/style:** **RuboCop** via `rubocop-rails-omakase`.

### Running / hosting
Phase 1 runs **locally** (`bin/dev`) against local PostgreSQL. No cloud dependency.
Deployment (if ever) via Kamal is the natural Rails-8 path; deferred.

---

## 4. Commands

```bash
bin/setup                     # install gems, prepare the PostgreSQL DB
bin/dev                       # start app + Tailwind watch (http://localhost:3000)
bin/rails db:prepare          # create + migrate the database
bin/rails db:seed             # load sample family (incl. Ba vợ / Ông ngoại case)
bin/rails console             # REPL
bin/importmap pin <lib>       # pin a JS library (e.g. the tree lib) — no Node build
bundle exec rspec             # run specs (kinship engine + domain + system)
bundle exec rspec spec/kinship # run just the kinship engine specs
bin/rubocop                   # lint / style (rubocop-rails-omakase)
bin/rails family:export FILE=family.json   # export whole tree to versioned JSON
bin/rails family:import FILE=family.json    # import a family JSON file
```

---

## 5. Project structure

```
viet_family/
├── CLAUDE.md                  # authoritative stack + workflow guidance
├── docs/                      # ALL generated docs (spec, plans, ADRs, reviews)
│   └── SPEC.md                # this file
├── app/
│   ├── kinship/               # PURE Ruby domain — NO Rails deps
│   │   ├── graph.rb           # build graph, derive siblings/children, path-finding
│   │   ├── terms.rb           # relationship-path → Vietnamese term (per dialect)
│   │   └── kinship.rb         # Kinship.term(...) entry point
│   ├── models/                # Person, Relationship, Note (ActiveRecord)
│   ├── services/
│   │   └── family/            # Exporter / Importer (versioned JSON schema)
│   ├── controllers/           # people, relationships, notes, tree, viewpoint
│   ├── views/                 # server-rendered HTML (Turbo Frames/Streams)
│   └── javascript/controllers # Stimulus controllers (tree viz is the main one)
├── db/
│   ├── migrate/
│   └── seeds.rb               # sample family exercising kinship edge cases
├── lib/tasks/family.rake      # export/import rake tasks
├── spec/
│   ├── kinship/               # table-driven kinship specs
│   ├── fixtures/kinship_vectors.json  # language-agnostic golden vectors
│   ├── services/              # exporter/importer round-trip specs
│   └── system/                # UI system tests
└── storage/                   # Active Storage portraits (local, git-ignored)
```

**Reuse rule:** controllers/views/services call into `app/kinship/` and the models; they
never re-implement relationship or term logic. All kinship rules live in exactly one place.

---

## 6. Code style

- Idiomatic Rails 8 conventions; **RuboCop** (Omakase/rails-omakase default) enforced.
- **Domain layer (`app/kinship/`) is pure**: deterministic POROs, no ActiveRecord, no I/O,
  no Rails constants. This is what makes it testable and mobile-portable.
- Keep the Vietnamese term/dialect data in one data module, separate from the traversal
  logic that consumes it.
- Represent relationships and terms with explicit value objects / symbols, not loose
  strings. Vietnamese terms stored/emitted with correct UTF-8 diacritics.
- Prefer small, named methods over deep conditionals in the term mapper.
- Skinny controllers; put non-trivial orchestration in `app/services/`.

---

## 7. Testing strategy

- **Kinship engine is tested first and hardest.** RSpec iterates the golden
  `kinship_vectors.json` — every `{viewer, target}` → expected term — over a fixed sample
  family. Must cover: paternal vs. maternal grandparents; bác vs. chú/cô and cậu/dì
  (seniority split); anh/chị/em by age; the **Ba vợ vs. Ông ngoại** perspective case; and
  graceful fallback for unreachable/unknown relationships.
- Every kinship bug fix adds a case to `kinship_vectors.json` (shared regression net).
- Graph builders (sibling/child derivation, path-finding) unit tested directly.
- **Exporter/Importer round-trip spec**: export → import → identical graph; schema version
  is asserted. This protects the mobile data contract.
- **System tests** (Capybara): create people, link them, click a node to change viewpoint,
  assert labels update; set a portrait and see it on the node.
- Target near-100% coverage on `app/kinship/`; UI coverage pragmatic.

---

## 8. Data contract: versioned JSON schema

The export format is a **first-class, versioned contract** (`schema_version` field), because
it is both the Phase-1 sharing mechanism and the future mobile app's data source. It carries
everything needed to rebuild the graph and recompute terms independently: people (id, name,
gender, birth_order, dates), relationships (parent/spouse edges), notes, dialect, and
portrait references (embedded or side-car — decide during build). Importer validates the
version and fails loudly on mismatch. Golden vectors (§2) live alongside this contract.

---

## 9. Future direction (Phase 2+, informing today's design only)

- **Mobile app, likely standalone/local-first**: holds its own copy, computes kinship
  on-device, shares via the JSON export from §8. Requires a second implementation of the
  kinship rules — kept honest by the shared golden vectors (§2). No server assumed.
- **Collaboration model deliberately undecided** (single keeper vs. a few editors merging
  vs. full sync). The versioned JSON schema keeps all three reachable; a lightweight sync
  server would only be added if "everyone edits, stays in sync" is chosen later.
- Auth, sharing/permissions, multi-photo media, and cloud deployment attach here.

---

## 10. Boundaries

**Always do**
- Keep all relationship & kinship-term logic in `app/kinship/` (pure, Rails-free).
- Extend `kinship_vectors.json` when touching kinship rules; treat it as ground truth for
  every implementation (Ruby now, mobile later).
- Bump `schema_version` and keep Importer/Exporter in sync when changing the JSON contract.
- Preserve Phase-2 paths (mobile/local-first, collaboration, deployment) — don't couple
  domain logic or the JSON format to Rails internals.
- Emit Vietnamese terms with correct diacritics (UTF-8).

**Ask first**
- Adding authentication, accounts, sharing/permissions, or any sync server (Phase 2).
- Adding multi-photo galleries or document attachments; moving portrait storage off local
  disk to a cloud/object store.
- Committing to a deployment provider or adding cloud infra.
- Swapping the tree visualization library or adding a heavy dependency.
- Changing the default dialect (currently Southern) or the JSON schema shape.

**Never do**
- Never expose family data publicly or add analytics/third-party trackers.
- Never hardcode one family's members into the domain logic (data lives in DB/seed/JSON).
- Never scatter kinship rules across controllers/views/services — one source of truth only.
- Never let the Ruby engine and the golden vectors disagree.

---

## Open items to confirm during build
- **Tree visualization library** inside the Stimulus controller (`relatives-tree` vs.
  d3-hierarchy vs. other) — pick when building the visualization.
- **Portrait handling in JSON export** — embed as base64 vs. side-car files in a zip.
