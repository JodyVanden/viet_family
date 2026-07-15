require "rails_helper"

RSpec.describe "People", type: :request do
  describe "GET /people" do
    it "lists people" do
      create(:person, name: "Ông Nội")
      get people_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ông Nội")
    end
  end

  describe "GET /people/:id" do
    it "shows a person" do
      person = create(:person, name: "Tôi")
      get person_path(person)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tôi")
    end
  end

  describe "GET /" do
    it "renders the people index at root" do
      get root_path
      expect(response).to have_http_status(:ok)
    end
  end
end
