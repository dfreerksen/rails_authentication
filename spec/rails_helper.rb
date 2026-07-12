# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

dummy_environment = File.expand_path("dummy/config/environment", __dir__)
unless File.exist?("#{dummy_environment}.rb")
  abort "spec/dummy is missing — generate it first with: bundle exec rake dummy:prepare"
end

require dummy_environment
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "spec_helper"
require "rspec/rails"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include ActiveSupport::Testing::TimeHelpers

  config.before do
    # deliver_later runs synchronously so specs can assert on ActionMailer::Base.deliveries
    ActiveJob::Base.queue_adapter = :inline
    ActionMailer::Base.deliveries.clear
  end
end
