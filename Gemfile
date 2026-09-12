# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "appraisal2" # test the generated code against multiple Rails lines — see Appraisals
gem "bcrypt" # the dummy app's has_secure_password runs against this bundle
gem "json", "< 3.0"
gem "puma" # bin/dev serves the dummy app against this bundle
gem "rails", ">= 8.0"
gem "rake"
gem "rspec", "~> 3.13"
gem "rspec-rails", "~> 8.0"
gem "sqlite3"
gem "webauthn" # request specs exercise the generated Passkey feature against this bundle
