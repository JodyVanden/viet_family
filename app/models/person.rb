class Person < ApplicationRecord
  GENDERS = %w[male female unknown].freeze

  enum :gender, GENDERS.index_by(&:itself), default: "unknown", validate: true

  validates :name, presence: true
  validates :birth_order, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :death_not_before_birth

  private

  def death_not_before_birth
    return if birth_date.blank? || death_date.blank?
    return if death_date >= birth_date

    errors.add(:death_date, "can't be before birth date")
  end
end
