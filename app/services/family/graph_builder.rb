module Family
  # Adapts persisted Person/Relationship records into a pure Kinship::Graph.
  # This is the ONLY bridge between ActiveRecord and the framework-free engine —
  # no kinship or relationship logic is re-implemented here.
  module GraphBuilder
    module_function

    def build(people: Person.all, relationships: Relationship.all)
      kinship_people = people.map { |p| to_kinship_person(p) }
      parent_edges = []
      spouse_edges = []

      relationships.each do |rel|
        if rel.kind == "parent"
          parent_edges << [ rel.to_person_id, rel.from_person_id ] # [child, parent]
        else
          spouse_edges << [ rel.from_person_id, rel.to_person_id ]
        end
      end

      Kinship::Graph.new(people: kinship_people, parent_edges: parent_edges, spouse_edges: spouse_edges)
    end

    def to_kinship_person(person)
      Kinship::Person.new(
        id: person.id,
        name: person.name,
        gender: person.gender.to_sym,
        birth_date: person.birth_date,
        death_date: person.death_date,
        birth_order: person.birth_order
      )
    end
  end
end
