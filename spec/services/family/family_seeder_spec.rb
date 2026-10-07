require "rails_helper"

# The real family is authored as FAMILIES — couple + children blocks — and each
# block expands into one spouse edge plus parent edges from both parents to
# every child. This keeps a child from ever getting mismatched parents.
RSpec.describe Family::FamilySeeder do
  it "creates every person and one relationship per expanded family edge" do
    described_class.seed!

    expected_parent_edges = described_class::FAMILIES.sum { |f| f[:parents].size * (f[:children] || []).size }
    expect(Person.count).to eq(described_class::PEOPLE.size)
    expect(Relationship.where(kind: "parent").count).to eq(expected_parent_edges)
    expect(Relationship.where(kind: "spouse").count).to eq(described_class::FAMILIES.size)
  end

  it "links every child to exactly the couple of its family block" do
    people = described_class.seed!

    described_class::FAMILIES.each do |family|
      (family[:children] || []).each do |child_name|
        child = people.fetch(child_name)
        parent_ids = Relationship.where(kind: "parent", to_person: child).pluck(:from_person_id)
        expect(parent_ids).to match_array(family[:parents].map { |name| people.fetch(name).id }),
          "#{child_name} should have parents #{family[:parents].join(', ')}"
      end
    end
  end

  it "is idempotent" do
    described_class.seed!
    expect { described_class.seed! }.not_to change { [ Person.count, Relationship.count ] }
  end

  it "yields correct perspective terms from persisted data" do
    people = described_class.seed!
    tree = Family::Tree.new

    # Owen's mother is Hanh, so her father Nam is his maternal grandfather.
    expect(tree.term_for(people.fetch("Owen Walker"), people.fetch("Nam Van Tran"))).to eq("Ông ngoại")
  end
end
