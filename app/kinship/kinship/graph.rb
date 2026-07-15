module Kinship
  # An immutable family graph: people plus parent (child → parent) and spouse
  # edges. Derives siblings/children/grandparents and finds relationship paths.
  # A DAG — every person may have two parents — not a simple tree.
  class Graph
    def initialize(people:, parent_edges:, spouse_edges:)
      @people = people.to_h { |p| [ p.id, p ] }
      @parents_of = Hash.new { |h, k| h[k] = [] }
      @children_of = Hash.new { |h, k| h[k] = [] }
      @spouses_of = Hash.new { |h, k| h[k] = [] }

      parent_edges.each do |child, parent|
        @parents_of[child] << parent
        @children_of[parent] << child
      end
      spouse_edges.each do |a, b|
        @spouses_of[a] << b
        @spouses_of[b] << a
      end
    end

    def person(id) = @people[id]

    def parents(id)  = @parents_of[id]
    def children(id) = @children_of[id]
    def spouses(id)  = @spouses_of[id]

    # People sharing at least one parent, excluding self.
    def siblings(id)
      parents(id).flat_map { |p| children(p) }.uniq - [ id ]
    end

    def father(id) = parents(id).find { |p| person(p)&.male? }
    def mother(id) = parents(id).find { |p| person(p)&.female? }

    def grandparents(id) = parents(id).flat_map { |p| parents(p) }.uniq
    def grandchildren(id) = children(id).flat_map { |c| children(c) }.uniq
  end
end
