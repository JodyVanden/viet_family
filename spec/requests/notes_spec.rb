require "rails_helper"

RSpec.describe "Notes", type: :request do
  let(:person) { create(:person) }

  it "adds a note (html)" do
    expect do
      post notes_path, params: { person_id: person.id, note: { body: "Loves phở." } }
    end.to change(person.notes, :count).by(1)
    expect(response).to redirect_to(person)
  end

  it "adds a note (turbo_stream)" do
    post notes_path, params: { person_id: person.id, note: { body: "Grew up in Huế." } },
                     as: :turbo_stream
    expect(response.media_type).to eq(Mime[:turbo_stream])
    expect(response.body).to include("Grew up in Huế.")
  end

  it "rejects a blank note" do
    post notes_path, params: { person_id: person.id, note: { body: "" } }
    expect(flash[:alert]).to be_present
  end

  it "removes a note" do
    note = create(:note, person: person)
    expect { delete note_path(note) }.to change(Note, :count).by(-1)
  end
end
