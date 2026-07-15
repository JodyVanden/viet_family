class TreeController < ApplicationController
  # Renders the interactive family tree. The kinship terms for every viewpoint are
  # precomputed here with the Ruby engine (an N×N matrix) so the client only has
  # to look them up — the engine is never reimplemented in JavaScript.
  def show
    @people = Person.order(:birth_date, :name).with_attached_portrait.to_a
    relationships = Relationship.all.to_a
    @tree = Family::Tree.new(people: @people, relationships: relationships)

    @parent_edges = relationships.select { |r| r.kind == "parent" }.map { |r| [ r.from_person_id, r.to_person_id ] }
    @spouse_edges = relationships.select { |r| r.kind == "spouse" }.map { |r| [ r.from_person_id, r.to_person_id ] }
    @levels = generation_levels(@people, @parent_edges, @spouse_edges)
    @terms = terms_matrix(@people, @tree)
  end

  private

  # Generation for each person: longest ancestry path (roots = 0), with married-in
  # spouses pulled to their partner's generation. Iterated to a fixpoint so both
  # constraints (a child is below its parents; spouses share a level) hold.
  def generation_levels(people, parent_edges, spouse_edges)
    ids = people.map(&:id)
    parents_of = Hash.new { |h, k| h[k] = [] }
    parent_edges.each { |parent, child| parents_of[child] << parent }
    level = Hash.new(0)

    (ids.size + 2).times do
      changed = false
      ids.each do |id|
        want = [ level[id], parents_of[id].map { |p| level[p] + 1 }.max || 0 ].max
        (level[id] = want) && (changed = true) if want != level[id]
      end
      spouse_edges.each do |a, b|
        shared = [ level[a], level[b] ].max
        (level[a] = shared) && (changed = true) if level[a] != shared
        (level[b] = shared) && (changed = true) if level[b] != shared
      end
      break unless changed
    end

    people.to_h { |p| [ p.id, level[p.id] ] }
  end

  # { viewer_id => { target_id => term } } for every ordered pair that has a real
  # kinship term. Pairs with no specific term are omitted (the client shows a
  # blank), which keeps the payload small and avoids repeating a distant
  # relative's name as its own "term".
  def terms_matrix(people, tree)
    people.to_h do |viewer|
      row = people.filter_map do |target|
        next if target.id == viewer.id

        term = tree.specific_term_for(viewer, target)
        [ target.id, term ] if term
      end
      [ viewer.id, row.to_h ]
    end
  end
end
