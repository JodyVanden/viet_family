require "rails_helper"

# T1.1 — the sample family and golden-vector files are well-formed and load into
# pure engine value objects. This is the foundation every later kinship spec builds on.
RSpec.describe "Kinship fixture integrity" do
  let(:people) { KinshipFixture.people }
  let(:ids) { people.map(&:id) }

  it "loads people as Kinship::Person value objects" do
    expect(people).to all(be_a(Kinship::Person))
    expect(people.size).to be >= 20
  end

  it "has unique person ids" do
    expect(ids.uniq).to eq(ids)
  end

  it "gives every person a valid gender" do
    expect(people.map(&:gender)).to all(be_in(%i[male female unknown]))
  end

  it "references only existing people in parent edges" do
    KinshipFixture.parent_edges.each do |child, parent|
      expect(ids).to include(child)
      expect(ids).to include(parent)
    end
  end

  it "references only existing people in spouse edges" do
    KinshipFixture.spouse_edges.each do |a, b|
      expect(ids).to include(a)
      expect(ids).to include(b)
    end
  end

  it "loads golden vectors with a dialect and a cases array" do
    data = KinshipFixture.vectors_data
    expect(data[:dialect]).to eq("southern")
    expect(data[:cases]).to be_an(Array)
  end
end
