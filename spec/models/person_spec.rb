require "rails_helper"

RSpec.describe Person, type: :model do
  it "has a valid factory" do
    expect(build(:person)).to be_valid
  end

  it "requires a name" do
    expect(build(:person, name: nil)).not_to be_valid
  end

  it "defaults gender to unknown" do
    expect(Person.new.gender).to eq("unknown")
  end

  it "accepts the known genders" do
    expect(build(:person, :male)).to be_valid
    expect(build(:person, :female)).to be_valid
  end

  it "rejects an invalid gender" do
    person = build(:person, gender: "alien")
    expect(person).not_to be_valid
    expect(person.errors[:gender]).to be_present
  end

  it "rejects a non-positive birth_order" do
    expect(build(:person, birth_order: 0)).not_to be_valid
    expect(build(:person, birth_order: 2)).to be_valid
  end

  it "rejects a death date before the birth date" do
    person = build(:person, birth_date: Date.new(1980, 1, 1), death_date: Date.new(1970, 1, 1))
    expect(person).not_to be_valid
    expect(person.errors[:death_date]).to be_present
  end
end
