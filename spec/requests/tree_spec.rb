require "rails_helper"

RSpec.describe "Tree", type: :request do
  it "renders the tree with node and term data" do
    people = Family::Seeder.seed!

    get tree_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("data-controller=\"tree\"")
    # Node data and the precomputed term matrix are embedded for the client.
    expect(response.body).to include(people.fetch("Ba Vợ").name)
    expect(response.body).to include("Ông ngoại")
  end

  it "renders gracefully with no people" do
    get tree_path
    expect(response).to have_http_status(:ok)
  end
end
