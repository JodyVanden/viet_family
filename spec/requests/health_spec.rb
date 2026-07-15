require "rails_helper"

# Smoke test: the app boots and its default health-check endpoint responds.
# Verifies the Rails/Propshaft/importmap/Tailwind scaffold is wired correctly.
RSpec.describe "Health check", type: :request do
  it "returns 200 from /up" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
