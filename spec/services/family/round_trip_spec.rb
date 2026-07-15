require "rails_helper"

# T3.2 — export → import reproduces the family exactly, protecting the mobile
# data contract. Terms computed before and after must be identical.
RSpec.describe "Family JSON round-trip" do
  it "reproduces people, relationships, notes, and terms" do
    people = Family::Seeder.seed!
    create(:note, person: people.fetch("Tôi"), body: "Middle child.")

    before_people = Person.count
    before_parents = Relationship.where(kind: "parent").count
    before_spouses = Relationship.where(kind: "spouse").count
    before_term_me = Family::Tree.new.term_for(people.fetch("Tôi"), people.fetch("Ba Vợ"))
    before_term_son = Family::Tree.new.term_for(people.fetch("Con Trai"), people.fetch("Ba Vợ"))

    json = Family::Exporter.as_json

    Relationship.delete_all
    Note.delete_all
    Person.destroy_all

    summary = Family::Importer.import(json)

    expect(summary[:people]).to eq(before_people)
    expect(Person.count).to eq(before_people)
    expect(Relationship.where(kind: "parent").count).to eq(before_parents)
    expect(Relationship.where(kind: "spouse").count).to eq(before_spouses)
    expect(Person.find_by(name: "Tôi").notes.pluck(:body)).to eq([ "Middle child." ])

    tree = Family::Tree.new
    me = Person.find_by!(name: "Tôi")
    bavo = Person.find_by!(name: "Ba Vợ")
    son = Person.find_by!(name: "Con Trai")
    expect(tree.term_for(me, bavo)).to eq(before_term_me)
    expect(tree.term_for(son, bavo)).to eq(before_term_son)
  end

  it "round-trips a portrait" do
    person = create(:person, name: "Có Hình")
    person.portrait.attach(io: StringIO.new("PNGDATA"), filename: "p.png", content_type: "image/png")

    json = Family::Exporter.as_json
    Person.destroy_all
    Family::Importer.import(json)

    restored = Person.find_by!(name: "Có Hình")
    expect(restored.portrait).to be_attached
    expect(restored.portrait.download).to eq("PNGDATA")
  end

  it "rejects an unsupported schema version" do
    expect { Family::Importer.import({ "schema_version" => 999, "people" => [], "relationships" => [] }) }
      .to raise_error(Family::Importer::UnsupportedSchema)
  end
end
