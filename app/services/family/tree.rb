module Family
  # A snapshot of the whole family, loaded once, that answers kinship questions
  # from any viewpoint. Wraps the pure engine so controllers/views never touch
  # Kinship::Graph directly.
  class Tree
    attr_reader :people

    def initialize(people: Person.all.to_a, relationships: Relationship.all.to_a, dialect: :southern)
      @people = people
      @dialect = dialect
      @graph = GraphBuilder.build(people: people, relationships: relationships)
    end

    # The Vietnamese term the viewer uses for the target (both are Person records
    # or ids), or the target's plain name when no term applies.
    def term_for(viewer, target)
      Kinship.term(viewer: id_of(viewer), target: id_of(target), graph: @graph, dialect: @dialect)
    end

    # The specific kinship term, or nil when there is none (no plain-name fallback).
    def specific_term_for(viewer, target)
      Kinship.specific_term(viewer: id_of(viewer), target: id_of(target), graph: @graph, dialect: @dialect)
    end

    private

    def id_of(person_or_id) = person_or_id.respond_to?(:id) ? person_or_id.id : person_or_id
  end
end
