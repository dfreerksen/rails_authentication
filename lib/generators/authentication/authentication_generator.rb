# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"
require_relative "features/confirmable"
require_relative "features/recoverable"
require_relative "features/registerable"
require_relative "features/rememberable"
require_relative "features/trackable"
require_relative "features/timeoutable"
require_relative "features/validatable"
require_relative "features/lockable"
require_relative "features/invitable"

module RailsAuthentication
  module Generators
    # Shadows Rails' built-in `bin/rails generate authentication` command: the explicit
    # `authentication:authentication` namespace is checked before Rails' own
    # `rails:authentication`, so the bare `authentication` invocation lands here.
    # It runs the built-in generator first, then layers the feature set on top.
    #
    # The Ruby namespace is RailsAuthentication (not Authentication, which would give the
    # same Thor namespace implicitly) because Rails 8's base generator creates an
    # `Authentication` controller concern in the host app — a top-level constant this gem
    # must not squat on.
    class AuthenticationGenerator < Rails::Generators::Base
      namespace "authentication:authentication"

      FEATURES = %i[
        confirmable recoverable registerable rememberable trackable
        timeoutable validatable lockable invitable
      ].freeze

      include ActiveRecord::Generators::Migration

      include Features::Confirmable
      include Features::Recoverable
      include Features::Registerable
      include Features::Rememberable
      include Features::Trackable
      include Features::Timeoutable
      include Features::Validatable
      include Features::Lockable
      include Features::Invitable

      source_root File.expand_path("templates", __dir__)

      FEATURES.each do |feature|
        class_option :"skip_#{feature}", type: :boolean, default: false,
          desc: "Skip #{feature}"
      end

      class_option :reconfirmable, type: :boolean, default: false,
        desc: "Confirmable: postpone email address changes until reconfirmed (adds unconfirmed_email column)"

      def install_base_authentication
        say "Running Rails' built-in authentication generator", :green
        Rails::Generators.invoke("rails:authentication", [], behavior: behavior, destination_root: destination_root)
      end

      def install_validatable
        generate_validatable if validatable?
      end

      def install_registerable
        generate_registerable if registerable?
      end

      def install_recoverable
        generate_recoverable if recoverable?
      end

      def install_confirmable
        generate_confirmable if confirmable?
      end

      def install_rememberable
        generate_rememberable if rememberable?
      end

      def install_trackable
        generate_trackable if trackable?
      end

      def install_timeoutable
        generate_timeoutable if timeoutable?
      end

      def install_lockable
        generate_lockable if lockable?
      end

      def install_invitable
        generate_invitable if invitable?
      end

      # Runs after every feature install so the blank line separates the concern
      # includes (if any) from the rest of the class body, no matter which features
      # are enabled.
      def format_user_model
        inject_into_file "app/models/user.rb", "\n", after: /(?:  include \w+Concern\n)+/, force: true
      end

      # Confirmable, Rememberable, Trackable, Timeoutable, and Lockable all hook into the
      # sign-in flow, so the base generator's session files are replaced with versions
      # rendered from the enabled feature set. Overwriting is safe: the base copies were
      # written moments ago by this same run.
      def customize_session_layer
        template "app/controllers/sessions_controller.rb", force: true
        template "app/controllers/concerns/authentication.rb", force: true
        template "app/views/sessions/new.html.erb", force: true
      end

      no_commands do
        FEATURES.each do |feature|
          define_method(:"#{feature}?") { !options[:"skip_#{feature}"] }
        end

        def reconfirmable?
          confirmable? && options[:reconfirmable]
        end

        def include_concern_in_user(concern)
          inject_into_class "app/models/user.rb", "User", "  include #{concern}\n"
        end

        def migration_version
          "[#{ActiveRecord::VERSION::STRING.to_f}]"
        end
      end
    end
  end
end
