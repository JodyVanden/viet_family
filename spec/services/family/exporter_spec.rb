require "rails_helper"

RSpec.describe Family::Exporter do
  it "produces the versioned, self-contained schema" do
    Family::Seeder.seed!
    hash = described_class.as_hash

    expect(hash["schema_version"]).to eq(Family::Exporter::SCHEMA_VERSION)
    expect(hash["dialect"]).to eq("southern")
    expect(hash["people"].size).to eq(Person.count)
    expect(hash["relationships"].size).to eq(Relationship.count)
  end

  it "embeds a portrait as base64" do
    person = create(:person)
    person.portrait.attach(io: StringIO.new("img"), filename: "p.png", content_type: "image/png")

    portrait = described_class.person_hash(person)["portrait"]
    expect(portrait["content_type"]).to eq("image/png")
    expect(Base64.strict_decode64(portrait["data"])).to eq("img")
  end

  it "records notes and relationship edges" do
    parent = create(:person)
    child = create(:person)
    create(:note, person: parent, body: "Loves phở.")
    create(:relationship, from_person: parent, to_person: child, kind: "parent")

    hash = described_class.as_hash
    expect(hash["people"].find { |p| p["ext_id"] == parent.id }["notes"]).to eq([ "Loves phở." ])
    expect(hash["relationships"]).to include("from" => parent.id, "to" => child.id, "kind" => "parent")
  end

  it "serializes to valid JSON" do
    Family::Seeder.seed!
    expect { JSON.parse(described_class.as_json) }.not_to raise_error
  end
end
