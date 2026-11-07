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
require_relative "features/magic_link"
require_relative "features/ott"
require_relative "features/passkey"

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
      include Features::MagicLink
      include Features::Ott
      include Features::Passkey

      source_root File.expand_path("templates", __dir__)

      FEATURES.each do |feature|
        class_option :"skip_#{feature}", type: :boolean, default: false, desc: "Skip #{feature}"
      end

      class_option :reconfirmable, type: :boolean, default: false,
                                   desc: "Confirmable: postpone email address changes until reconfirmed (opt-in)"

      # Unlike the FEATURES above (default-on, opt-out via --skip-<feature>),
      # magic link is opt-in: it changes the sign-in UX, so it must be requested.
      class_option :magic_link, type: :boolean, default: false, desc: "Add passwordless magic link sign-in (opt-in)"

      # Also opt-in: replaces the sign-in form with an email-only form that
      # emails a 6-digit one-time code, entered on a second screen. Password
      # machinery stays generated and functional.
      class_option :ott, type: :boolean, default: false,
                         desc: "Add one-time token (emailed 6-digit code) sign-in (opt-in)"

      # Also opt-in: WebAuthn passkey sign-in alongside password sign-in.
      # Requires the host app to add the `webauthn` gem itself.
      class_option :passkey, type: :boolean, default: false,
                             desc: "Add WebAuthn passkey sign-in (opt-in; requires the webauthn gem)"

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

      def install_magic_link
        generate_magic_link if magic_link?
      end

      def install_ott
        generate_ott if ott?
      end

      def install_passkey
        generate_passkey if passkey?
      end

      # Runs after every feature install so the blank line separates the concern
      # includes (if any) from the rest of the class body, no matter which features
      # are enabled.
      def format_user_model
        inject_into_file "app/models/user.rb", "\n", after: /(?:  include \w+Concern\n)+/, force: true
      end

      # User.available / User.unavailable: whether a user can sign in, composed from the scopes of
      # whichever of Confirmable, Lockable, and Invitable are enabled. Placed, as a block of its
      # own, after the base generator's `has_many :sessions` line.
      def add_user_scopes
        return if available_user_scope_chain.empty?

        scopes = [
          "scope :available, -> { #{available_user_scope_chain.join('.')} }",
          "scope :unavailable, -> { where.not(id: available) }"
        ]
        inject_into_file "app/models/user.rb", "\n#{scopes.map { |line| "  #{line}\n" }.join}",
                         after: /^  has_many :sessions, dependent: :destroy\n/, force: true
      end

      # The instance-level counterparts of User.available / User.unavailable, from the same
      # enabled features, placed after the base generator's `normalizes :email_address` line.
      # active_for_authentication? is Devise's name for the same check.
      def add_user_availability_predicates
        return if availability_checks.empty?

        inject_into_file "app/models/user.rb", "\n#{user_availability_predicates}",
                         after: /^  normalizes :email_address, .*\n/, force: true
      end

      # Confirmable, Rememberable, Trackable, Timeoutable, and Lockable all hook into the
      # sign-in flow, so the base generator's session files are replaced with versions
      # rendered from the enabled feature set. Overwriting is safe: the base copies were
      # written moments ago by this same run. The Session model carries the expiry rules
      # (Timeoutable's inactivity timeout, Rememberable's REMEMBERED_TIMEOUT_IN cap).
      def customize_session_layer
        template "app/models/session.rb", force: true
        template "app/controllers/sessions_controller.rb", force: true
        template "app/controllers/concerns/authentication.rb", force: true
        template "app/views/sessions/new.html.erb", force: true
      end

      def create_locale_file
        template "config/locales/authentication.en.yml"
      end

      no_commands do
        FEATURES.each do |feature|
          define_method(:"#{feature}?") { !options[:"skip_#{feature}"] }
        end

        # The maxlength for new-password fields: Validatable's policy when it's generated,
        # otherwise has_secure_password's hard limit (bcrypt's 72 bytes).
        def password_maxlength
          return "ValidatableConcern::PASSWORD_LENGTH.max" if validatable?

          "ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED"
        end

        def reconfirmable?
          confirmable? && options[:reconfirmable]
        end

        def magic_link?
          options[:magic_link]
        end

        def ott?
          options[:ott]
        end

        def passkey?
          options[:passkey]
        end

        # [available-when check, unavailable-when check] per enabled feature, matching the scopes.
        def availability_checks
          [
            (["!locked?", "locked?"] if lockable?),
            (["confirmed?", "!confirmed?"] if confirmable?),
            (["!invitation_pending?", "invitation_pending?"] if invitable?)
          ].compact
        end

        def user_availability_predicates
          available = availability_checks.map(&:first).join(" &&\n      ")
          unavailable = availability_checks.map(&:last).join(" ||\n      ")

          "  def available?\n    #{available}\n  end\n  alias active_for_authentication? available?\n\n" \
            "  def unavailable?\n    #{unavailable}\n  end\n"
        end

        # Mirrors the sign-in checks: confirmed, not currently locked, no invitation outstanding.
        def available_user_scope_chain
          [
            ("confirmed" if confirmable?),
            ("not_locked" if lockable?),
            ("not_pending" if invitable?)
          ].compact
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
