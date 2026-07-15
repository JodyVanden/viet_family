require "base64"

module Family
  # Rebuilds a family from the versioned JSON contract produced by Exporter.
  # Additive (does not clear existing data) and transactional. Fails loudly on an
  # unsupported schema version so the mobile data contract can evolve safely.
  module Importer
    class UnsupportedSchema < StandardError; end

    module_function

    # Accepts a JSON string or a parsed Hash. Returns a summary of what was created.
    def import(source)
      data = source.is_a?(String) ? JSON.parse(source) : source
      version = data["schema_version"]
      unless version == Exporter::SCHEMA_VERSION
        raise UnsupportedSchema, "unsupported schema_version: #{version.inspect}"
      end

      ActiveRecord::Base.transaction do
        id_map = create_people(data.fetch("people"))
        create_relationships(data.fetch("relationships"), id_map)
        { people: id_map.size, relationships: data["relationships"].size }
      end
    end

    def create_people(people)
      people.to_h do |attrs|
        person = Person.create!(
          name: attrs["name"],
          gender: attrs["gender"],
          birth_date: attrs["birth_date"],
          death_date: attrs["death_date"],
          birth_order: attrs["birth_order"]
        )
        attach_portrait(person, attrs["portrait"])
        Array(attrs["notes"]).each { |body| person.notes.create!(body: body) }
        [ attrs["ext_id"], person ]
      end
    end

    def create_relationships(relationships, id_map)
      relationships.each do |rel|
        Relationship.create!(
          from_person: id_map.fetch(rel["from"]),
          to_person: id_map.fetch(rel["to"]),
          kind: rel["kind"]
        )
      end
    end

    def attach_portrait(person, portrait)
      return if portrait.nil?

      person.portrait.attach(
        io: StringIO.new(Base64.decode64(portrait["data"])),
        filename: portrait["filename"],
        content_type: portrait["content_type"]
      )
    end
  end
end
