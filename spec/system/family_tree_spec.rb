require "rails_helper"

RSpec.describe "Family tree", type: :system, js: true do
  it "renders each person as a node" do
    Family::Seeder.seed!

    visit tree_path
    expect(page).to have_css("[data-node-id]", minimum: 20)
    expect(page).to have_css(".node-name", text: "Ba Vợ")
  end
end
