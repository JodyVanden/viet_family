require "base64"

module Family
  # Serializes the whole family to the versioned JSON contract (docs/SPEC.md §8).
  # This format is the sharing mechanism now and the future mobile app's data
  # source, so it is self-contained: portraits are embedded as base64 and people
  # are referenced by a stable ext_id (their current DB id) within the file.
  module Exporter
    SCHEMA_VERSION = 1

    module_function

    def as_hash(dialect: "southern")
      {
        "schema_version" => SCHEMA_VERSION,
        "dialect" => dialect.to_s,
        "people" => Person.includes(:notes).order(:id).map { |p| person_hash(p) },
        "relationships" => Relationship.order(:id).map { |r| relationship_hash(r) }
      }
    end

    def as_json(dialect: "southern", pretty: true)
      hash = as_hash(dialect: dialect)
      pretty ? JSON.pretty_generate(hash) : JSON.generate(hash)
    end

    def person_hash(person)
      {
        "ext_id" => person.id,
        "name" => person.name,
        "gender" => person.gender,
        "birth_date" => person.birth_date&.iso8601,
        "death_date" => person.death_date&.iso8601,
        "birth_order" => person.birth_order,
        "portrait" => portrait_hash(person),
        "notes" => person.notes.map(&:body)
      }
    end

    def relationship_hash(rel)
      { "from" => rel.from_person_id, "to" => rel.to_person_id, "kind" => rel.kind }
    end

    def portrait_hash(person)
      return nil unless person.portrait.attached?

      {
        "filename" => person.portrait.filename.to_s,
        "content_type" => person.portrait.content_type,
        "data" => Base64.strict_encode64(person.portrait.download)
      }
    end
  end
end
