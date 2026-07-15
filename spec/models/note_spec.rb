require "rails_helper"

RSpec.describe Note, type: :model do
  it "has a valid factory" do
    expect(build(:note)).to be_valid
  end

  it "requires a body" do
    expect(build(:note, body: "")).not_to be_valid
  end

  it "belongs to a person" do
    expect(build(:note, person: nil)).not_to be_valid
  end

  it "is destroyed with its person" do
    person = create(:person)
    create(:note, person: person)
    expect { person.destroy }.to change(Note, :count).by(-1)
  end
end
