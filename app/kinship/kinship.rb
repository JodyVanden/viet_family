# Kinship — pure, framework-free domain logic for Vietnamese kinship terms.
#
# The word used for a relative depends on WHO is viewing (paternal vs. maternal
# side, seniority, gender). Nothing in this namespace may reference ActiveRecord,
# Rails, or perform I/O — that is what keeps it exhaustively testable and portable
# to a future mobile app. See docs/SPEC.md §2.
module Kinship
  module_function

  # Seniority of person +a+ relative to +b+, used to distinguish sibling-based
  # terms (bác vs. chú, anh/chị vs. em). Precedence: compare reliable birth_dates;
  # otherwise fall back to birth_order; otherwise :unknown. Returns one of
  # :older, :younger, :same, or :unknown. Only meaningful for siblings, where
  # birth_order is comparable.
  def seniority(a, b)
    cmp =
      if a.birth_date && b.birth_date
        a.birth_date <=> b.birth_date
      elsif a.birth_order && b.birth_order
        a.birth_order <=> b.birth_order
      end
    return :unknown if cmp.nil?
    return :same if cmp.zero?

    cmp.negative? ? :older : :younger
  end

  # Boolean shortcut: is +a+ strictly older/senior to +b+? (:unknown ⇒ false).
  def senior?(a, b) = seniority(a, b) == :older

  # The Vietnamese kinship term the +viewer+ uses for the +target+, computed over
  # +graph+ in the given +dialect+. Returns the target's plain name when no term
  # applies, or nil if either id is unknown.
  def term(viewer:, target:, graph:, dialect: :southern)
    Terms.new(graph, dialect).term(viewer, target)
  end

  # Like `term`, but returns nil (rather than the plain name) when no specific
  # kinship term applies — so callers can omit meaningless entries.
  def specific_term(viewer:, target:, graph:, dialect: :southern)
    Terms.new(graph, dialect).specific_term(viewer, target)
  end
end
