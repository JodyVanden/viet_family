module TreeHelper
  # Node data for the tree Stimulus controller: id, name, gender, generation
  # level, and a portrait URL (nil when none is attached).
  def tree_nodes_json(people, levels)
    people.map do |person|
      {
        id: person.id,
        name: person.name,
        gender: person.gender,
        level: levels.fetch(person.id, 0),
        portrait_url: person.portrait.attached? ? url_for(person.portrait) : nil
      }
    end.to_json
  end
end
