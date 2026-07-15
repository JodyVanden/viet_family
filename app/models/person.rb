class Person < ApplicationRecord
  GENDERS = %w[male female unknown].freeze

  enum :gender, GENDERS.index_by(&:itself), default: "unknown", validate: true

  has_many :outgoing_relationships, class_name: "Relationship",
           foreign_key: :from_person_id, dependent: :destroy, inverse_of: :from_person
  has_many :incoming_relationships, class_name: "Relationship",
           foreign_key: :to_person_id, dependent: :destroy, inverse_of: :to_person

  validates :name, presence: true
  validates :birth_order, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :death_not_before_birth

  # Parents are the from_person of incoming `parent` edges; children the
  # to_person of outgoing ones. Spouses come from either direction.
  def parents
    Person.where(id: incoming_relationships.where(kind: "parent").select(:from_person_id))
  end

  def children
    Person.where(id: outgoing_relationships.where(kind: "parent").select(:to_person_id))
  end

  def spouses
    ids = outgoing_relationships.where(kind: "spouse").pluck(:to_person_id) +
          incoming_relationships.where(kind: "spouse").pluck(:from_person_id)
    Person.where(id: ids)
  end

  private

  def death_not_before_birth
    return if birth_date.blank? || death_date.blank?
    return if death_date >= birth_date

    errors.add(:death_date, "can't be before birth date")
  end
end
