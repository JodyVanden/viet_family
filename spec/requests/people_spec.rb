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


  describe "POST /people" do
    it "creates a person" do
      expect do
        post people_path, params: { person: { name: "Bà Nội", gender: "female" } }
      end.to change(Person, :count).by(1)
      expect(response).to redirect_to(Person.last)
    end

    it "re-renders on invalid input" do
      post people_path, params: { person: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /people/:id" do
    it "updates a person" do
      person = create(:person, name: "Old")
      patch person_path(person), params: { person: { name: "New" } }
      expect(response).to redirect_to(person)
      expect(person.reload.name).to eq("New")
    end
  end

  describe "DELETE /people/:id" do
    it "removes a person" do
      person = create(:person)
      expect { delete person_path(person) }.to change(Person, :count).by(-1)
      expect(response).to redirect_to(people_path)
    end
  end
end
