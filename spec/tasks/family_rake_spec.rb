require "rails_helper"
require "rake"

RSpec.describe "family:* rake tasks" do
  before do
    Rake.application = Rake::Application.new
    Rails.application.load_tasks
  end

  it "exports to a file and imports it back" do
    Family::Seeder.seed!
    original_people = Person.count
    path = Rails.root.join("tmp", "family_#{SecureRandom.hex(4)}.json")
    ENV["FILE"] = path.to_s

    Rake::Task["family:export"].invoke
    expect(File).to exist(path)

    Relationship.delete_all
    Person.destroy_all
    Rake::Task["family:import"].invoke

    expect(Person.count).to eq(original_people)
  ensure
    File.delete(path) if path && File.exist?(path)
    ENV.delete("FILE")
  end
end
