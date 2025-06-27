FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    token_version { 1 }

    trait :with_messages do
      after(:create) do |user|
        create_list(:message, 3, user: user)
      end
    end
  end
end
