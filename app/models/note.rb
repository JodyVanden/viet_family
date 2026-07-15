class Note < ApplicationRecord
  belongs_to :person

  validates :body, presence: true
end
