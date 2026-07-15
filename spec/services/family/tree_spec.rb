require "rails_helper"

# T2.5 — end-to-end: persisted records flow through the adapter into the pure
# engine and produce the correct Vietnamese terms, including the perspective case.
RSpec.describe Family::Tree do
  let!(:father) { create(:person, :male, name: "Ba", birth_date: Date.new(1958, 7, 22)) }
  let!(:me) { create(:person, :male, name: "Tôi", birth_date: Date.new(1985, 9, 9)) }
  let!(:wife) { create(:person, :female, name: "Vợ", birth_date: Date.new(1986, 4, 4)) }
  let!(:wife_father) { create(:person, :male, name: "Ba Vợ", birth_date: Date.new(1958, 3, 3)) }
  let!(:son) { create(:person, :male, name: "Con", birth_date: Date.new(2010, 1, 1)) }

  before do
    create(:relationship, from_person: father, to_person: me, kind: "parent")
    create(:relationship, from_person: wife_father, to_person: wife, kind: "parent")
    create(:relationship, :spouse, from_person: me, to_person: wife)
    create(:relationship, from_person: me, to_person: son, kind: "parent")
    create(:relationship, from_person: wife, to_person: son, kind: "parent")
  end

  subject(:tree) { described_class.new }

  it "computes a parent term from persisted data" do
    expect(tree.term_for(me, father)).to eq("Ba")
  end

  it "computes the father-in-law term for the husband" do
    expect(tree.term_for(me, wife_father)).to eq("Ba vợ")
  end

  it "computes the maternal-grandfather term for the son (same person, other viewpoint)" do
    expect(tree.term_for(son, wife_father)).to eq("Ông ngoại")
  end

  it "accepts ids as well as records" do
    expect(tree.term_for(me.id, father.id)).to eq("Ba")
  end
end
