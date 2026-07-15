FactoryBot.define do
  factory :person do
    sequence(:name) { |n| "Person #{n}" }
    gender { "unknown" }

    trait :male do
      gender { "male" }
    end

    trait :female do
      gender { "female" }
    end
  end
end
