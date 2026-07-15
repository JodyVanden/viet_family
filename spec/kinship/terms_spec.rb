require "rails_helper"

# T1.9 — engine branches not exercised by the golden vectors: dialect switching,
# unknown-dialect handling, and the older-female cousin term.
RSpec.describe Kinship::Terms do
  let(:graph) { KinshipFixture.graph }

  it "uses the Northern dialect words for parents when requested" do
    expect(Kinship.term(viewer: :me, target: :father, graph: graph, dialect: :northern)).to eq("Bố")
    expect(Kinship.term(viewer: :me, target: :mother, graph: graph, dialect: :northern)).to eq("Mẹ")
  end

  it "raises for an unknown dialect" do
    expect { Kinship.term(viewer: :me, target: :father, graph: graph, dialect: :klingon) }
      .to raise_error(ArgumentError, /unknown dialect/)
  end

  it "calls an older female cousin Chị họ" do
    people = [
      Kinship::Person.new(id: :gp, name: "GP", gender: :male),
      Kinship::Person.new(id: :p1, name: "P1", gender: :male, birth_order: 1),
      Kinship::Person.new(id: :p2, name: "P2", gender: :male, birth_order: 2),
      Kinship::Person.new(id: :older_cousin, name: "OC", gender: :female, birth_date: Date.new(2000, 1, 1)),
      Kinship::Person.new(id: :viewer, name: "V", gender: :male, birth_date: Date.new(2005, 1, 1))
    ]
    parents = [ [ :p1, :gp ], [ :p2, :gp ], [ :older_cousin, :p1 ], [ :viewer, :p2 ] ]
    g = Kinship::Graph.new(people: people, parent_edges: parents, spouse_edges: [])

    expect(Kinship.term(viewer: :viewer, target: :older_cousin, graph: g)).to eq("Chị họ")
  end
end
