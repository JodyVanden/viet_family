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

    # The kinship term String, or the target's plain name when no term applies;
    # nil if either person is unknown.
    def term(viewer_id, target_id)
      target = @graph.person(target_id)
      return nil if target.nil? || @graph.person(viewer_id).nil?

      specific_term(viewer_id, target_id) || target.name
    end

    # The specific kinship term, or nil when there is none (unknown people or a
    # distant/unclassified relationship). Callers wanting a display fallback use
    # `term` instead.
    def specific_term(viewer_id, target_id)
      viewer = @graph.person(viewer_id)
      target = @graph.person(target_id)
      return nil if viewer.nil? || target.nil?
      return spouse_term(target) if @graph.spouses(viewer_id).include?(target.id)
      return @vocab[:father] if parent?(viewer_id, target) && target.male?
      return @vocab[:mother] if parent?(viewer_id, target) && target.female?

      in_law = parent_in_law_term(viewer_id, target)
      return in_law if in_law

      return "Con" if @graph.children(viewer_id).include?(target.id)
      return "Cháu" if descendant?(viewer_id, target.id)

      grandparent = grandparent_term(viewer_id, target)
      return grandparent if grandparent

      sibling = sibling_term(viewer, target)
      return sibling if sibling

      pibling = pibling_term(viewer_id, target)
      return pibling if pibling

      cousin_term(viewer, target)
    end

    private

    def parent?(viewer_id, target)
      @graph.parents(viewer_id).include?(target.id)
    end

    def spouse_term(target) = target.male? ? "Chồng" : "Vợ"

    # Cháu covers both grandchildren and the children of one's siblings.
    def descendant?(viewer_id, target_id)
      return true if @graph.grandchildren(viewer_id).include?(target_id)

      @graph.siblings(viewer_id).any? { |s| @graph.children(s).include?(target_id) }
    end

    # Anh/Chị họ (older) or Em họ (younger) for a cousin — the child of a parent's
    # sibling; nil otherwise.
    def cousin_term(viewer, target)
      cousins = @graph.parents(viewer.id)
                      .flat_map { |p| @graph.siblings(p) }
                      .flat_map { |s| @graph.children(s) }
      return nil unless cousins.include?(target.id)

      if Kinship.seniority(target, viewer) == :older
        target.male? ? "Anh họ" : "Chị họ"
      else
        "Em họ"
      end
    end

    # Ba/Má vợ (spouse is a wife) or Ba/Má chồng (spouse is a husband) when the
    # target is a parent of the viewer's spouse; nil otherwise.
    def parent_in_law_term(viewer_id, target)
      @graph.spouses(viewer_id).each do |spouse_id|
        next unless @graph.parents(spouse_id).include?(target.id)

        suffix = @graph.person(spouse_id).female? ? "vợ" : "chồng"
        base = target.male? ? @vocab[:father] : @vocab[:mother]
        return "#{base} #{suffix}"
      end
      nil
    end

    # Anh/Chị (older) by gender, or Em (younger); nil if not a sibling.
    def sibling_term(viewer, target)
      return nil unless @graph.siblings(viewer.id).include?(target.id)

      if Kinship.seniority(target, viewer) == :older
        target.male? ? "Anh" : "Chị"
      else
        "Em"
      end
    end

    # Ông/Bà nội (paternal) or ngoại (maternal), or nil if not a grandparent.
    def grandparent_term(viewer_id, target)
      return nil unless @graph.grandparents(viewer_id).include?(target.id)

      side = grandparent_side(viewer_id, target.id)
      return nil unless side

      honorific = target.male? ? "Ông" : "Bà"
      "#{honorific} #{side}"
    end

    # A parent's sibling (bác/chú/cô/cậu/dì) or their spouse (bác gái/thím/mợ/
    # dượng), or nil. Southern rule: Bác = father's OLDER brother only; his
    # younger brother is Chú; all father's sisters are Cô; all mother's brothers
    # are Cậu and all her sisters Dì (no maternal Bác).
    def pibling_term(viewer_id, target)
      blood = blood_pibling_term(viewer_id, target)
      return blood if blood

      # Aunt/uncle by marriage: target is the spouse of a blood aunt/uncle.
      @graph.spouses(target.id).each do |spouse_id|
        base = blood_pibling_term(viewer_id, @graph.person(spouse_id))
        return SPOUSE_OF_PIBLING[base] if base
      end
      nil
    end

    # Term for a person who is a blood sibling of the viewer's parent, else nil.
    def blood_pibling_term(viewer_id, person)
      father = @graph.father(viewer_id)
      mother = @graph.mother(viewer_id)

      if father && @graph.siblings(father).include?(person.id)
        return "Cô" unless person.male?

        Kinship.senior?(person, @graph.person(father)) ? "Bác" : "Chú"
      elsif mother && @graph.siblings(mother).include?(person.id)
        person.male? ? "Cậu" : "Dì"
      end
    end

    # The term for the spouse of a blood aunt/uncle, keyed by that relative's term.
    SPOUSE_OF_PIBLING = {
      "Bác" => "Bác gái",
      "Chú" => "Thím",
      "Cô" => "Dượng",
      "Cậu" => "Mợ",
      "Dì" => "Dượng"
    }.freeze

    def grandparent_side(viewer_id, grandparent_id)
      father = @graph.father(viewer_id)
      mother = @graph.mother(viewer_id)
      return "nội" if father && @graph.parents(father).include?(grandparent_id)
      return "ngoại" if mother && @graph.parents(mother).include?(grandparent_id)

      # simplecov:disable — defensive; grandparent_term only calls this for grandparents.
      nil
      # simplecov:enable
    end
  end
end
