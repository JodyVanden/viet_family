require "rails_helper"

RSpec.describe "Managing a person", type: :system do
  it "adds a person with a portrait through the form" do
    visit new_person_path

    fill_in "Name", with: "Ông Nội"
    select "Male", from: "Gender"
    fill_in "Born", with: "1930-03-10"
    attach_file "Portrait", Rails.root.join("spec/fixtures/files/portrait.png")
    click_button "Create Person"

    expect(page).to have_content("Person was added.")
    expect(page).to have_content("Ông Nội")
    expect(Person.find_by(name: "Ông Nội").portrait).to be_attached
  end

  it "shows validation errors" do
    visit new_person_path
    fill_in "Name", with: ""
    click_button "Create Person"
    expect(page).to have_content("prevented saving")
  end
end
