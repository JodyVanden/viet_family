require "rails_helper"

RSpec.describe "Family tree", type: :system, js: true do
  it "renders a focus view centred on a person" do
    Family::Seeder.seed!

    visit tree_path
    expect(page).to have_content("Centred on")
    # A focus view shows the focal person's own line, not the entire family.
    expect(page).to have_css("[data-node-id]", minimum: 8)
    expect(page).to have_css(".node-name", text: "Tôi")
    expect(page).to have_css(".node-name", text: "Con Trai")
  end

  it "re-centres the tree when another person is clicked" do
    people = Family::Seeder.seed!

    visit tree_path
    find("[data-node-id='#{people.fetch("Ba").id}'] .node-name", text: "Ba").click
    expect(page).to have_content("Centred on Ba")
  end
end
