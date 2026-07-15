require "rails_helper"

RSpec.describe Relationship, type: :model do
  it "has a valid factory" do
    expect(build(:relationship)).to be_valid
  end

  it "requires a known kind" do
    expect(build(:relationship, kind: "friend")).not_to be_valid
  end

  it "rejects relating a person to themselves" do
    person = create(:person)
    expect(build(:relationship, from_person: person, to_person: person)).not_to be_valid
  end

  it "rejects a duplicate parent edge" do
    parent = create(:person)
    child = create(:person)
    create(:relationship, from_person: parent, to_person: child, kind: "parent")
    expect(build(:relationship, from_person: parent, to_person: child, kind: "parent")).not_to be_valid
  end

  it "rejects a reverse-duplicate spouse edge" do
    a = create(:person)
    b = create(:person)
    create(:relationship, :spouse, from_person: a, to_person: b)
    expect(build(:relationship, :spouse, from_person: b, to_person: a)).not_to be_valid
  end

  it "rejects a parent edge that would create a cycle" do
    grandparent = create(:person)
    parent = create(:person)
    create(:relationship, from_person: grandparent, to_person: parent, kind: "parent")
    # Making grandparent a child of parent would create a cycle.
    expect(build(:relationship, from_person: parent, to_person: grandparent, kind: "parent")).not_to be_valid
  end

  describe "Person graph helpers" do
    it "exposes parents, children, and spouses" do
      dad = create(:person, :male)
      mom = create(:person, :female)
      kid = create(:person)
      create(:relationship, from_person: dad, to_person: kid, kind: "parent")
      create(:relationship, from_person: mom, to_person: kid, kind: "parent")
      create(:relationship, :spouse, from_person: dad, to_person: mom)

      expect(kid.parents).to contain_exactly(dad, mom)
      expect(dad.children).to contain_exactly(kid)
      expect(dad.spouses).to contain_exactly(mom)
      expect(mom.spouses).to contain_exactly(dad)
    end
  end
end
