require "rails_helper"

RSpec.describe "Browsing people", type: :system do
  it "opens a person from the family list" do
    create(:person, name: "Ông Nội", birth_date: Date.new(1930, 1, 1))

    visit people_path
    expect(page).to have_content("Family")

    click_link "Ông Nội"
    expect(page).to have_content("Ông Nội")
    expect(page).to have_content("Stories & notes")
  end
end
