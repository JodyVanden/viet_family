require "rails_helper"

RSpec.describe "Person portrait", type: :model do
  def attach(person, content_type:, bytes: "fake-image-data")
    person.portrait.attach(io: StringIO.new(bytes), filename: "p.img", content_type: content_type)
  end

  it "accepts a PNG/JPEG/WebP portrait" do
    person = create(:person)
    attach(person, content_type: "image/png")
    expect(person).to be_valid
  end

  it "rejects a non-image portrait" do
    person = create(:person)
    attach(person, content_type: "text/plain")
    expect(person).not_to be_valid
    expect(person.errors[:portrait]).to be_present
  end

  it "rejects a portrait larger than 5 MB" do
    person = create(:person)
    attach(person, content_type: "image/png", bytes: "x" * (5.megabytes + 1))
    expect(person).not_to be_valid
    expect(person.errors[:portrait]).to be_present
  end

  it "is valid with no portrait attached" do
    expect(create(:person)).to be_valid
  end
end
