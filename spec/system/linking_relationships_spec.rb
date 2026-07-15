require "rails_helper"

RSpec.describe "Linking relationships", type: :system do
  it "links a parent from the person page" do
    me = create(:person, name: "Tôi")
    create(:person, name: "Ba", gender: "male")

    visit person_path(me)
    within("section", text: "Relationships") do
      select "Parent", from: "relation"
      select "Ba", from: "related_person_id"
      click_button "Link"
    end

    expect(page).to have_content("Relationship added.")
    expect(me.reload.parents.map(&:name)).to include("Ba")
  end
end
