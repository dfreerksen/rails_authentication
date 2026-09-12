# frozen_string_literal: true

# Each appraisal builds its own Gemfile (in gemfiles/) that starts from the root Gemfile
# and pins `rails` to one supported line, so CI catches a Rails-release regression (like
# the one that broke CI on 2026-09-11) against a specific version instead of "whatever
# rails resolved to today."
#
# After editing this file: `bundle exec appraisal generate-install`, then commit the
# resulting gemfiles/*.gemfile (the *.gemfile.lock files are gitignored — CI re-resolves
# them fresh so a new Rails patch release inside a supported line still gets exercised).

appraise "rails-8.0-json-2" do
  gem "rails", "~> 8.0.0"
  gem "json", "~> 2.7"
end

appraise "rails-8.1-json-2" do
  gem "rails", "~> 8.1.0"
  gem "json", "~> 2.7"
end

appraise "rails-8.0-json-3" do
  gem "rails", "~> 8.0.0"
  # Pinned to the exact 3.0.0 release: json 3.0.2 (released 2026-09-09) ships a broken
  # gem package for MRI — ext/json/ext/generator/extconf.rb is present in the git tag but
  # missing from the .gem itself, so `bundle install` fails with "No such file or
  # directory -- extconf.rb (LoadError)" trying to build the native extension. Once json
  # publishes a working 3.0.x release, relax this back to "~> 3.0".
  gem "json", "3.0.0"
end

appraise "rails-8.1-json-3" do
  gem "rails", "~> 8.1.0"
  # See the rails-8.0-json-3 appraisal above re: pinning away from broken json 3.0.2.
  gem "json", "3.0.0"
end
