require "rails_helper"

# T2.6 — the seed builds a consistent family that yields correct terms, and is
# idempotent (safe to run repeatedly).
RSpec.describe Family::Seeder do
  it "creates the whole sample family" do
    described_class.seed!
    expect(Person.count).to eq(Family::Seeder::PEOPLE.size)
    expect(Relationship.where(kind: "parent").count).to eq(Family::Seeder::PARENTS.size)
    expect(Relationship.where(kind: "spouse").count).to eq(Family::Seeder::SPOUSES.size)
  end

  it "is idempotent" do
    described_class.seed!
    expect { described_class.seed! }.not_to change(Person, :count)
  end

  it "yields the driving perspective case from persisted data" do
    people = described_class.seed!
    tree = Family::Tree.new
    expect(tree.term_for(people.fetch("Tôi"), people.fetch("Ba Vợ"))).to eq("Ba vợ")
    expect(tree.term_for(people.fetch("Con Trai"), people.fetch("Ba Vợ"))).to eq("Ông ngoại")
  end
end
