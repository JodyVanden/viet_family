# Loads the canonical sample family (spec/fixtures/kinship_family.json) into
# pure Kinship::Person objects plus raw parent/spouse edges. Test support only —
# the engine itself never reads files.
module KinshipFixture
  FAMILY_PATH = Rails.root.join("spec/fixtures/kinship_family.json")
  VECTORS_PATH = Rails.root.join("spec/fixtures/kinship_vectors.json")

  module_function

  def family_data
    JSON.parse(FAMILY_PATH.read, symbolize_names: true)
  end

  def vectors_data
    JSON.parse(VECTORS_PATH.read, symbolize_names: true)
  end

  def people
    family_data[:people].map do |p|
      Kinship::Person.new(
        id: p[:id].to_sym,
        name: p[:name],
        gender: p[:gender].to_sym,
        birth_date: p[:birth_date] && Date.parse(p[:birth_date]),
        death_date: p[:death_date] && Date.parse(p[:death_date]),
        birth_order: p[:birth_order]
      )
    end
  end

  def parent_edges
    family_data[:parents].map { |e| [ e[:child].to_sym, e[:parent].to_sym ] }
  end

  def spouse_edges
    family_data[:spouses].map { |e| [ e[:a].to_sym, e[:b].to_sym ] }
  end

  # A Kinship::Graph built from the fixture (available once Graph exists).
  def graph
    Kinship::Graph.new(people: people, parent_edges: parent_edges, spouse_edges: spouse_edges)
  end
end
