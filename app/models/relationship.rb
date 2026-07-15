class Relationship < ApplicationRecord
  KINDS = %w[parent spouse].freeze

  belongs_to :from_person, class_name: "Person"
  belongs_to :to_person, class_name: "Person"

  # For a `parent` edge, from_person is the parent and to_person is the child.
  # A `spouse` edge is symmetric (stored once).
  validates :kind, inclusion: { in: KINDS }
  validates :from_person_id, uniqueness: { scope: %i[to_person_id kind] }
  validate :endpoints_differ
  validate :no_reverse_spouse_duplicate
  validate :no_parent_cycle

  private

  def endpoints_differ
    return if from_person_id.nil? || to_person_id.nil?
    return if from_person_id != to_person_id

    errors.add(:to_person, "can't be the same person")
  end

  def no_reverse_spouse_duplicate
    return unless kind == "spouse"
    return unless Relationship.exists?(kind: "spouse", from_person_id: to_person_id, to_person_id: from_person_id)

    errors.add(:base, "spouse relationship already exists")
  end

  # Adding "from_person is parent of to_person" creates a cycle when to_person is
  # already an ancestor of from_person.
  def no_parent_cycle
    return unless kind == "parent"
    return if from_person_id.nil? || to_person_id.nil?
    return unless ancestor?(to_person_id, of: from_person_id)

    errors.add(:base, "would create a parent cycle")
  end

  # Is `candidate` reachable by following parent edges upward from `person_id`?
  def ancestor?(candidate, of:)
    frontier = [ of ]
    seen = []
    until frontier.empty?
      current = frontier.shift
      seen << current
      parent_ids = Relationship.where(kind: "parent", to_person_id: current).pluck(:from_person_id)
      return true if parent_ids.include?(candidate)

      frontier.concat(parent_ids - seen)
    end
    false
  end
end
