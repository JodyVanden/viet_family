class TreeController < ApplicationController
  # Renders the interactive family tree. The kinship terms for every viewpoint are
  # precomputed here with the Ruby engine (an N×N matrix) so the client only has
  # to look them up — the engine is never reimplemented in JavaScript.
  def show
    @people = Person.order(:birth_date, :name).to_a
    relationships = Relationship.all.to_a
    @tree = Family::Tree.new(people: @people, relationships: relationships)

    @parent_edges = relationships.select { |r| r.kind == "parent" }.map { |r| [ r.from_person_id, r.to_person_id ] }
    @spouse_edges = relationships.select { |r| r.kind == "spouse" }.map { |r| [ r.from_person_id, r.to_person_id ] }
    @levels = generation_levels(@people, @parent_edges)
    @terms = terms_matrix(@people, @tree)
  end

  private

  # Longest-path generation for each person (roots = 0), used for vertical layout.
  def generation_levels(people, parent_edges)
    parents_of = Hash.new { |h, k| h[k] = [] }
    parent_edges.each { |parent, child| parents_of[child] << parent }

    memo = {}
    level = lambda do |id|
      memo[id] ||= parents_of[id].empty? ? 0 : parents_of[id].map { |p| level.call(p) }.max + 1
    end
    people.to_h { |p| [ p.id, level.call(p.id) ] }
  end

  # { viewer_id => { target_id => term } } for every ordered pair of people.
  def terms_matrix(people, tree)
    people.to_h do |viewer|
      [ viewer.id, people.reject { |t| t.id == viewer.id }.to_h { |t| [ t.id, tree.term_for(viewer, t) ] } ]
    end
  end
end
