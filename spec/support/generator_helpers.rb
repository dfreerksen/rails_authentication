# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "action_mailer/railtie" # so the generator's `defined?(ActionMailer::Railtie)` guards are exercised
require "minitest/assertions"
require "active_support/testing/assertions"
require "rails/generators/testing/assertions"
require "generators/authentication/authentication_generator"

# A deliberately small stand-in for Rails::Generators::TestCase (whose run_generator
# injects default arguments our generator doesn't declare). Provides destination
# management, a run_generator that starts the generator class directly, and mixes in
# Rails' assert_file / assert_migration assertions.
module GeneratorHelpers
  include Minitest::Assertions
  include ActiveSupport::Testing::Assertions
  include Rails::Generators::Testing::Assertions

  attr_accessor :assertions

  def destination_root
    @destination_root ||= File.expand_path("../../tmp/destination", __dir__)
  end

  def prepare_destination
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)
    seed_base_app_files
  end

  # The feature steps inject into and route against files the base rails:authentication
  # generator produces. Specs stub that (shelling-out) base invocation, so seed its
  # relevant output here instead.
  def seed_base_app_files
    write_destination_file "config/routes.rb", <<~RUBY
      Rails.application.routes.draw do
      end
    RUBY

    write_destination_file "app/models/user.rb", <<~RUBY
      class User < ApplicationRecord
        has_secure_password
        has_many :sessions, dependent: :destroy

        normalizes :email_address, with: ->(e) { e.strip.downcase }
      end
    RUBY

    write_destination_file "app/controllers/application_controller.rb", <<~RUBY
      class ApplicationController < ActionController::Base
      end
    RUBY
  end

  def write_destination_file(relative, content)
    absolute = File.expand_path(relative, destination_root)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, content)
  end

  def run_generator(args = [])
    capture_stdout do
      RailsAuthentication::Generators::AuthenticationGenerator.start(args, destination_root: destination_root)
    end
  end

  # Rails::Generators::Testing::Behavior provides this alongside run_generator; since we
  # don't use Behavior, assert_migration needs a local copy.
  def migration_file_name(relative)
    absolute = File.expand_path(relative, destination_root)
    dirname = File.dirname(absolute)
    file_name = File.basename(absolute, ".rb")
    Dir.glob("#{dirname}/[0-9]*_*.rb").grep(/\d+_#{file_name}\.rb$/).first
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end

RSpec.configure do |config|
  config.include GeneratorHelpers, type: :generator

  config.before(:each, type: :generator) do
    self.assertions = 0
    allow(Rails::Generators).to receive(:invoke) # the base generator shells out; stub it
    prepare_destination
  end
end
