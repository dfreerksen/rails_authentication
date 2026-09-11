# frozen_string_literal: true

# Each appraisal builds its own Gemfile (in gemfiles/) that starts from the root Gemfile
# and pins `rails` to one supported line, so CI catches a Rails-release regression (like
# the one that broke CI on 2026-09-11) against a specific version instead of "whatever
# rails resolved to today."
#
# After editing this file: `bundle exec appraisal generate-install`, then commit the
# resulting gemfiles/*.gemfile (the *.gemfile.lock files are gitignored — CI re-resolves
# them fresh so a new Rails patch release inside a supported line still gets exercised).

appraise "rails-8.0" do
  gem "rails", "~> 8.0.0"
end

appraise "rails-8.1" do
  gem "rails", "~> 8.1.0"
end
