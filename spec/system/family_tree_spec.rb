require "rails_helper"

RSpec.describe "Family tree", type: :system, js: true do
  it "renders the whole family" do
    Family::Seeder.seed!

    visit tree_path
    # Everyone is shown; clicking never hides anyone.
    expect(page).to have_css("[data-node-id]", minimum: 20)
    expect(page).to have_css(".node-name", text: "Tôi")
    expect(page).to have_css(".node-name", text: "Con Trai")
  end

  it "re-labels from a person's perspective without hiding anyone" do
    people = Family::Seeder.seed!

    visit tree_path
    before = page.evaluate_script("document.querySelectorAll('[data-node-id]').length")

    find("[data-node-id='#{people.fetch("Ba").id}'] .node-name", text: "Ba").click
    expect(page).to have_content("Showing how Ba")

    after = page.evaluate_script("document.querySelectorAll('[data-node-id]').length")
    expect(after).to eq(before)
  end
end
