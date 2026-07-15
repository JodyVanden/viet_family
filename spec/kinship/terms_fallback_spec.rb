require "rails_helper"

# T1.8 — graceful behaviour when no term applies. Uncovered or unreachable
# relationships must never raise; they return the target's plain name. Unknown
# ids return nil.
RSpec.describe "Kinship.term fallback" do
  let(:graph) { KinshipFixture.graph }

  it "returns the plain name for a relationship with no kinship term" do
    # A cousin's spouse's relation etc. is not modelled; use an unreachable person
    # with a distinctive name so we know we got the name, not a coincidental term.
    stranger = Kinship::Person.new(id: :stranger, name: "Người Lạ", gender: :male)
    g = Kinship::Graph.new(people: KinshipFixture.people + [ stranger ],
                           parent_edges: KinshipFixture.parent_edges,
                           spouse_edges: KinshipFixture.spouse_edges)
    expect(Kinship.term(viewer: :me, target: :stranger, graph: g)).to eq("Người Lạ")
  end

  it "returns the plain name for an out-of-table relationship (great-grandparent)" do
    # son -> ong_ngoai is a great-grandparent, which the Southern table omits.
    expect(Kinship.term(viewer: :son, target: :ong_ngoai, graph: graph)).to eq("Ông Ngoại")
  end

  it "returns nil when either person is unknown" do
    expect(Kinship.term(viewer: :me, target: :nobody, graph: graph)).to be_nil
    expect(Kinship.term(viewer: :nobody, target: :me, graph: graph)).to be_nil
  end
end
