# frozen_string_literal: true

require_relative "lib/rails_authentication/version"

Gem::Specification.new do |spec|
  spec.name = "rails_authentication"
  spec.version = RailsAuthentication::VERSION
  spec.authors = ["David Freerksen"]
  spec.email = ["dfreerksen@gmail.com"]

  spec.summary = "Devise-style features on top of Rails 8's built-in authentication generator"
  spec.description = "Extends `bin/rails generate authentication` to install Confirmable, " \
                     "Recoverable, Registerable, Rememberable, Trackable, Timeoutable, " \
                     "Validatable, Lockable, and Invitable — all generated into your app " \
                     "as plain, editable code."
  spec.homepage = "https://github.com/dfreerksen/rails_authentication"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 8.0"
end
