require "rails_helper"

# Tree layout rework (docs/TREE_LAYOUT_SPEC.md, docs/TREE_LAYOUT_PLAN.md).
# Uses the real seeded family shape (Family::FamilySeeder's fictional demo data),
# not the kinship fixture family in family_tree_spec.rb, because the layout bugs
# were found against this richer, asymmetric family shape.
RSpec.describe "Family tree layout", type: :system, js: true do
  it "orders Nam Van Tran and Hoa Thi Pham's children by seniority, not by who has kids (R1)" do
    people = Family::FamilySeeder.seed!
    visit tree_path

    # Hanh Thi Tran is the eldest of the three but the only one with children of
    # her own (Owen, Mia). Before the fix, unitChildren() sorted childless
    # siblings first, pushing her to the end despite being eldest. R1 requires
    # pure seniority order instead: Hanh, Yen, Son.
    hanh = node_x(people, "Hanh Thi Tran")
    yen = node_x(people, "Yen Thi Tran")
    son = node_x(people, "Son Van Tran")

    expect(hanh).to be < yen
    expect(yen).to be < son
  end

  it "faces married-in spouses away from the blood siblings they sit beside (R2)" do
    people = Family::FamilySeeder.seed!
    visit tree_path

    # Suong Thi Tran is the leftmost of Hung/Lan's children, so her husband Khoi
    # Van Dinh must sit to her *left* (outward), not between her and a sibling.
    suong = node_x(people, "Suong Thi Tran")
    khoi = node_x(people, "Khoi Van Dinh")
    expect(khoi).to be < suong

    # Phong Van Tran sits mid-row (Suong, Loc before him; Hien, Thu, Dat after),
    # with fewer siblings on his left, so his wife My Thi Vo goes there too.
    phong = node_x(people, "Phong Van Tran")
    my = node_x(people, "My Thi Vo")
    expect(my).to be < phong
  end

  it "places a linking couple at the shared edge between the two families they join (R3)" do
    people = Family::FamilySeeder.seed!
    visit tree_path

    # Nam Van Tran married Hoa Thi Pham, whose own parents (Dao Van Pham, Nga
    # Thi Le) are also rendered. Before the fix, Nam stayed in strict seniority
    # order, so the Pham family's bus line had to reach back across his other
    # siblings' subtrees to reach Hoa. R3 moves Nam to the edge of his row
    # nearest the Pham block instead.
    suong = node_x(people, "Suong Thi Tran")
    loc = node_x(people, "Loc Van Tran")
    phong = node_x(people, "Phong Van Tran")
    nam = node_x(people, "Nam Van Tran")
    dao = node_x(people, "Dao Van Pham")

    expect(nam).to be > [ suong, loc, phong ].max

    # The Pham block starts after Phong's whole subtree, not wedged before or
    # crossing back over it.
    expect(dao).to be > phong
  end

  it "keeps every family's children contiguous in their row, with no other family wedged between them (R4)" do
    Family::FamilySeeder.seed!
    visit tree_path

    # General form of R3's fix, checked for every family in the tree (not just
    # the Tran/Pham pair named above): a family's bus line only ever spans its
    # own children, never reaches past a foreign family to get to one of them.
    # Before T3, this failed for Dao Van Pham + Nga Thi Le: their children (Hoa
    # Thi Pham, Mai Thi Pham) were separated by the whole Tran sibling row, so
    # several unrelated people sat between them in their generation.
    data = page.evaluate_script(<<~JS)
      (function() {
        const el = document.querySelector('[data-controller="tree"]')
        const controller = Stimulus.getControllerForElementAndIdentifier(el, "tree")
        const positions = {}
        controller.positions.forEach((pos, id) => { positions[id] = pos.x })
        const levels = {}
        controller.level.forEach((lvl, id) => { levels[id] = lvl })
        const spouseOf = {}
        controller.spouseOf.forEach((spouse, id) => { spouseOf[id] = spouse })
        const families = controller.families
          .filter((f) => f.children.length > 0)
          .map((f) => ({ children: f.children }))
        return { positions, levels, spouseOf, families }
      })()
    JS

    positions = data.fetch("positions")
    levels = data.fetch("levels")
    spouse_of = data.fetch("spouseOf")

    data.fetch("families").each do |family|
      children = family.fetch("children").map(&:to_s)
      # A child's own spouse legitimately sits beside them in the row (R2) —
      # that's not a foreign family wedged in, it's part of this couple.
      expected = children.flat_map { |c| [ c, spouse_of[c]&.to_s ] }.compact.uniq

      level = levels.fetch(children.first)
      row = levels.select { |_id, lvl| lvl == level }.keys.sort_by { |id| positions.fetch(id) }

      span = row[row.index(expected.min_by { |id| positions.fetch(id) })..row.index(expected.max_by { |id| positions.fetch(id) })]

      expect(span).to match_array(expected),
        "expected only #{expected.inspect} between them in their row, but found #{span.inspect}"
    end
  end

  def node_x(people, name)
    id = people.fetch(name).id
    page.evaluate_script("parseFloat(document.querySelector('[data-node-id=\"#{id}\"]').style.left)")
  end
end
