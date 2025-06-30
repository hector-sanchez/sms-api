source "https://rubygems.org"

gem "bcrypt"
gem "bootsnap", require: false
gem "jwt"
gem "kamal", require: false
gem "mongoid", "~> 8.1"
gem "puma", ">= 5.0"
gem "rails", "~> 8.0.2"
gem "thruster", require: false
gem "twilio-ruby"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem 'dotenv-rails'
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "pry"
  gem "pry-rails"
end

group :test do
  gem "database_cleaner-mongoid"
  gem "factory_bot_rails"
  gem "faker"
  gem "mongoid-rspec"
  gem "rspec-rails"
end
