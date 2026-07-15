FactoryBot.define do
  factory :relationship do
    association :from_person, factory: :person
    association :to_person, factory: :person
    kind { "parent" }

    trait :spouse do
      kind { "spouse" }
    end
  end
end
