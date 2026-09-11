# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      # Opt-in (--passkey): WebAuthn-based passkey sign-in, in addition to
      # password sign-in. A user may register any number of passkeys
      # (platform authenticators, security keys); sign-in is usernameless —
      # the browser's discoverable-credential picker stands in for an email
      # field. Ceremony verification is delegated to the `webauthn` gem —
      # unlike everything else this gem generates, that's a real runtime
      # dependency, so it's added straight to the host app's Gemfile.
      module Passkey
        private

        def generate_passkey
          gem "webauthn", comment: "Verifies WebAuthn passkey registration/authentication ceremonies"
          say "Added the `webauthn` gem to your Gemfile — run `bundle install`.", :yellow

          template "config/initializers/webauthn.rb"
          template "app/models/concerns/passkey_concern.rb"
          include_concern_in_user "PasskeyConcern"
          template "app/models/webauthn_credential.rb"
          migration_template "db/migrate/add_webauthn_id_to_users.rb", "db/migrate/add_webauthn_id_to_users.rb"
          migration_template "db/migrate/create_webauthn_credentials.rb", "db/migrate/create_webauthn_credentials.rb"
          template "app/controllers/webauthn_credentials_controller.rb"
          template "app/controllers/passkey_sessions_controller.rb"
          template "app/views/webauthn_credentials/index.html.erb"
          template "app/views/webauthn_credentials/new.html.erb"
          route "resources :webauthn_credentials, only: %i[ index new create destroy ]"
          route "resource :passkey_session, only: %i[ create ], controller: \"passkey_sessions\""
        end
      end
    end
  end
end
