require "rails_helper"

RSpec.describe "Adding notes", type: :system do
  it "adds a note to a person" do
    person = create(:person, name: "Tôi")

    visit person_path(person)
    within("#note-form") do
      fill_in "note[body]", with: "Middle child of four."
      click_button "Add note"
    end

    expect(page).to have_content("Middle child of four.")
  end
end
