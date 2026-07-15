require "rails_helper"

RSpec.describe "Person portrait", type: :model do
  def png_bytes
    File.binread(Rails.root.join("spec/fixtures/files/portrait.png"))
  end

  # Attach to an unsaved record so the pending upload is inspected before save,
  # mirroring the real form flow.
  def attach(person, bytes:, content_type: "image/png")
    person.portrait.attach(io: StringIO.new(bytes), filename: "p.img", content_type: content_type)
  end

  it "accepts a real PNG portrait" do
    person = build(:person)
    attach(person, bytes: png_bytes)
    expect(person).to be_valid
  end

  it "rejects a file whose bytes are not an image, even if labelled image/png" do
    person = build(:person)
    attach(person, bytes: "definitely not an image", content_type: "image/png")
    expect(person).not_to be_valid
    expect(person.errors[:portrait]).to be_present
  end

  it "rejects a portrait larger than 5 MB" do
    person = build(:person)
    attach(person, bytes: png_bytes + ("\0" * 5.megabytes))
    expect(person).not_to be_valid
    expect(person.errors[:portrait]).to be_present
  end

  it "is valid with no portrait attached" do
    expect(build(:person)).to be_valid
  end
end
