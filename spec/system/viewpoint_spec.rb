require "rails_helper"

# The headline feature: the same person is named differently depending on whom
# the tree is centred on. Clicking a person re-centres the tree on them.
RSpec.describe "Viewpoint relabelling", type: :system, js: true do
  it "shows Ba Vợ as 'Ba vợ' to the husband but 'Ông ngoại' to the son" do
    people = Family::Seeder.seed!
    me = people.fetch("Tôi")
    son = people.fetch("Con Trai")
    father_in_law = people.fetch("Ba Vợ")

    visit tree_path

    # Centre on the son: his mother's father is his maternal grandfather.
    find("[data-node-id='#{son.id}'] .node-name", text: "Con Trai").click
    within("[data-node-id='#{father_in_law.id}']") do
      expect(page).to have_css(".node-term", text: "Ông ngoại")
    end

    # Centre on the husband: the same man is his father-in-law.
    find("[data-node-id='#{me.id}'] .node-name", text: "Tôi").click
    within("[data-node-id='#{father_in_law.id}']") do
      expect(page).to have_css(".node-term", text: "Ba vợ")
    end
  end
end
