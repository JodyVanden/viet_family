namespace :family do
  desc "Export the whole family to versioned JSON (FILE=path/to/family.json)"
  task export: :environment do
    path = ENV.fetch("FILE")
    File.write(path, Family::Exporter.as_json)
    puts "Exported #{Person.count} people and #{Relationship.count} relationships to #{path}"
  end

  desc "Import a family from versioned JSON (FILE=path/to/family.json)"
  task import: :environment do
    path = ENV.fetch("FILE")
    summary = Family::Importer.import(File.read(path))
    puts "Imported #{summary[:people]} people and #{summary[:relationships]} relationships from #{path}"
  end
end
