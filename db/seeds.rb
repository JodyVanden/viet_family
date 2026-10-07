# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Real family data is private and never committed (see .gitignore). If it has
# been exported locally to db/seed_data/family.local.json (via Family::Exporter),
# load that; otherwise fall back to the fictional demo family (Family::FamilySeeder),
# which includes the driving perspective case: "Ba Vợ" is the husband's
# father-in-law but the son's maternal grandfather (Ông ngoại).
private_family_path = Rails.root.join("db/seed_data/family.local.json")

if File.exist?(private_family_path)
  Family::Importer.import(File.read(private_family_path))
  puts "Imported private family: #{Person.count} people and #{Relationship.count} relationships."
else
  Family::FamilySeeder.seed!
  puts "Seeded demo family: #{Person.count} people and #{Relationship.count} relationships."
end
