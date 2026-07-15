module Kinship
  # An immutable person in the family graph. Only the attributes that kinship
  # terms depend on live here; display-only data (portraits, notes) does not.
  #
  # - gender:      :male, :female, or :unknown
  # - birth_date:  Date or nil (primary seniority signal)
  # - birth_order: Integer or nil (fallback seniority signal among siblings)
  Person = Data.define(:id, :name, :gender, :birth_date, :death_date, :birth_order) do
    def initialize(id:, name:, gender: :unknown, birth_date: nil, death_date: nil, birth_order: nil)
      super
    end

    def male? = gender == :male
    def female? = gender == :female
  end
end
