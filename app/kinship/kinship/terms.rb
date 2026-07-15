module Kinship
  # Maps a (viewer, target) pair to the Vietnamese kinship term the viewer uses
  # for the target. Classifies the relationship by category over the graph, then
  # picks the exact word from side (nội/ngoại, in-law), generation, seniority,
  # and gender. Unknown/unreachable relationships fall back to the plain name.
  class Terms
    def initialize(graph, dialect = :southern)
      @graph = graph
      @vocab = Dialects.fetch(dialect)
    end

    # Returns the term String, or nil if either person is unknown.
    def term(viewer_id, target_id)
      viewer = @graph.person(viewer_id)
      target = @graph.person(target_id)
      return nil if viewer.nil? || target.nil?
      return @vocab[:father] if parent?(viewer_id, target) && target.male?
      return @vocab[:mother] if parent?(viewer_id, target) && target.female?

      grandparent = grandparent_term(viewer_id, target)
      return grandparent if grandparent

      # Fallback: no known term — use the person's own name.
      target.name
    end

    private

    def parent?(viewer_id, target)
      @graph.parents(viewer_id).include?(target.id)
    end

    # Ông/Bà nội (paternal) or ngoại (maternal), or nil if not a grandparent.
    def grandparent_term(viewer_id, target)
      return nil unless @graph.grandparents(viewer_id).include?(target.id)

      side = grandparent_side(viewer_id, target.id)
      return nil unless side

      honorific = target.male? ? "Ông" : "Bà"
      "#{honorific} #{side}"
    end

    def grandparent_side(viewer_id, grandparent_id)
      father = @graph.father(viewer_id)
      mother = @graph.mother(viewer_id)
      return "nội" if father && @graph.parents(father).include?(grandparent_id)
      return "ngoại" if mother && @graph.parents(mother).include?(grandparent_id)

      nil
    end
  end
end
