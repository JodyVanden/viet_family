require "rails_helper"

# T1.2 — the graph derives siblings/children/grandparents and finds relationship
# paths over the DAG (two parents per person, plus spouse edges).
RSpec.describe Kinship::Graph do
  let(:graph) { KinshipFixture.graph }

  it "looks up a person by id" do
    expect(graph.person(:me).name).to eq("Tôi")
    expect(graph.person(:nobody)).to be_nil
  end

  it "returns parents and children" do
    expect(graph.parents(:me)).to contain_exactly(:father, :mother)
    expect(graph.children(:me)).to contain_exactly(:son, :daughter)
  end

  it "returns spouses symmetrically" do
    expect(graph.spouses(:me)).to contain_exactly(:wife)
    expect(graph.spouses(:wife)).to contain_exactly(:me)
  end

  it "derives siblings from shared parents, excluding self" do
    expect(graph.siblings(:me)).to contain_exactly(:anh, :chi, :em_gai)
  end

  it "picks father and mother by gender" do
    expect(graph.father(:me)).to eq(:father)
    expect(graph.mother(:me)).to eq(:mother)
    expect(graph.father(:ong_noi)).to be_nil
  end

  it "returns all four grandparents" do
    expect(graph.grandparents(:me)).to contain_exactly(:ong_noi, :ba_noi, :ong_ngoai, :ba_ngoai)
  end

  it "returns grandchildren (children of children, not children)" do
    expect(graph.grandchildren(:father)).to contain_exactly(:son, :daughter, :niece)
  end

  it "finds the shortest relationship path" do
    expect(graph.shortest_path(:me, :me)).to eq([ :me ])
    expect(graph.shortest_path(:me, :father)).to eq([ :me, :father ])
    expect(graph.shortest_path(:me, :ong_noi)).to eq([ :me, :father, :ong_noi ])
  end

  it "returns nil for an unreachable person" do
    isolated = Kinship::Person.new(id: :ghost, name: "Ghost")
    g = Kinship::Graph.new(people: KinshipFixture.people + [ isolated ],
                           parent_edges: KinshipFixture.parent_edges,
                           spouse_edges: KinshipFixture.spouse_edges)
    expect(g.shortest_path(:me, :ghost)).to be_nil
  end
end
