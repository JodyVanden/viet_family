class Person < ApplicationRecord
  GENDERS = %w[male female unknown].freeze
  PORTRAIT_TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_PORTRAIT_BYTES = 5.megabytes

  enum :gender, GENDERS.index_by(&:itself), default: "unknown", validate: true

  has_one_attached :portrait

  has_many :outgoing_relationships, class_name: "Relationship",
           foreign_key: :from_person_id, dependent: :destroy, inverse_of: :from_person
  has_many :incoming_relationships, class_name: "Relationship",
           foreign_key: :to_person_id, dependent: :destroy, inverse_of: :to_person
  has_many :notes, dependent: :destroy

  validates :name, presence: true
  validates :birth_order, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :death_not_before_birth
  validate :portrait_is_a_reasonable_image

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

  def portrait_is_a_reasonable_image
    return unless portrait.attached?

    unless sniffed_portrait_type.in?(PORTRAIT_TYPES)
      errors.add(:portrait, "must be a PNG, JPEG, or WebP image")
    end
    if portrait.blob.byte_size.to_i > MAX_PORTRAIT_BYTES
      errors.add(:portrait, "must be smaller than 5 MB")
    end
  end

  # The real image type, detected from the file's magic bytes rather than the
  # client-declared content type (which can be spoofed). Falls back to the blob's
  # stored type when the pending upload isn't readable here.
  def sniffed_portrait_type
    io = pending_portrait_io
    return portrait.blob.content_type unless io.respond_to?(:read)

    io.rewind if io.respond_to?(:rewind)
    Marcel::MimeType.for(io, name: portrait.filename.to_s)
  ensure
    io.rewind if io.respond_to?(:rewind)
  end

  def pending_portrait_io
    attachable = attachment_changes["portrait"]&.attachable
    case attachable
    when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile then attachable.tempfile
    when Hash then attachable[:io]
    when IO, StringIO then attachable
    end
  end
end
