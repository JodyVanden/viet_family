require "rails_helper"

RSpec.describe "Relationships", type: :request do
  let(:person) { create(:person, name: "Tôi") }
  let(:other) { create(:person, name: "Ba") }

  it "links a parent" do
    post relationships_path, params: { person_id: person.id, related_person_id: other.id, relation: "parent" }
    expect(response).to redirect_to(person)
    expect(person.parents).to include(other)
  end

  it "links a child" do
    post relationships_path, params: { person_id: person.id, related_person_id: other.id, relation: "child" }
    expect(person.children).to include(other)
  end

  it "links a spouse" do
    post relationships_path, params: { person_id: person.id, related_person_id: other.id, relation: "spouse" }
    expect(person.spouses).to include(other)
  end

  it "reports a validation failure" do
    post relationships_path, params: { person_id: person.id, related_person_id: person.id, relation: "spouse" }
    expect(response).to redirect_to(person)
    expect(flash[:alert]).to be_present
  end

  it "unlinks a relationship" do
    rel = create(:relationship, from_person: other, to_person: person, kind: "parent")
    expect { delete relationship_path(rel, person_id: person.id) }.to change(Relationship, :count).by(-1)
    expect(response).to redirect_to(person_path(person))
  end
end
