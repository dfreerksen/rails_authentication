# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "bcrypt" # the dummy app's has_secure_password runs against this bundle
gem "json", "~> 2.7" # pin below the 2.9/2.10 line implicated in ActiveSupport#to_json arity collisions
gem "puma" # bin/dev serves the dummy app against this bundle
gem "rails", ">= 8.0", "< 8.1"
gem "rake"
gem "rspec", "~> 3.13"
gem "rspec-rails", "~> 8.0"
gem "sqlite3"
gem "webauthn" # request specs exercise the generated Passkey feature against this bundle
