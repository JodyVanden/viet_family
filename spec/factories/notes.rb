FactoryBot.define do
  factory :note do
    association :person
    body { "A short family anecdote." }
  end
end
