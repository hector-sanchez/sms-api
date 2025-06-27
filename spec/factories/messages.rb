FactoryBot.define do
  factory :message do
    body { "Hello, this is a test message!" }
    sequence(:to) { |n| "+1234567890#{n.to_s.rjust(2, '0')}" }
    association :user

    trait :long_message do
      body { "This is a very long message that exceeds the typical SMS length limit. " * 5 }
    end

    trait :short_message do
      body { "Hi!" }
    end

    trait :with_emoji do
      body { "Hello! 😊 How are you doing today? 🎉" }
    end
  end
end
