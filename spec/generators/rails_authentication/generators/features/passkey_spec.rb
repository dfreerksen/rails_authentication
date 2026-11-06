# frozen_string_literal: true

RSpec.describe RailsAuthentication::Generators::Features::Passkey, type: :generator do
  it "is left out by default (opt-in)" do
    run_generator

    %w[
      config/initializers/webauthn.rb
      app/models/concerns/passkey_concern.rb
      app/models/webauthn_credential.rb
      app/controllers/webauthn_credentials_controller.rb
      app/controllers/passkey_sessions_controller.rb
      app/views/webauthn_credentials/index.html.erb
      app/views/webauthn_credentials/new.html.erb
    ].each { |path| assert_no_file path }
    %w[
      db/migrate/add_webauthn_id_to_users.rb
      db/migrate/create_webauthn_credentials.rb
    ].each { |path| assert_no_migration path }
    assert_file("app/models/user.rb") { |user| expect(user).not_to include("PasskeyConcern") }
    assert_file("config/routes.rb") { |routes| expect(routes).not_to include("webauthn_credentials") }
    assert_file("config/routes.rb") { |routes| expect(routes).not_to include("passkey_session") }
    assert_file("app/controllers/sessions_controller.rb") { |controller| expect(controller).not_to include("WebAuthn") }
    assert_file("app/views/sessions/new.html.erb") { |view| expect(view).not_to include("passkey") }
    assert_file("Gemfile") { |gemfile| expect(gemfile).not_to include("webauthn") }
  end

  it "generates the initializer, concern, model, migrations, controllers, views, and routes with --passkey" do
    run_generator %w[--passkey]

    assert_file "config/initializers/webauthn.rb", /WebAuthn\.configure do \|config\|/
    assert_file "app/models/concerns/passkey_concern.rb",
                /has_many :webauthn_credentials, dependent: :destroy/,
                /def ensure_webauthn_id/,
                /WebAuthn\.generate_user_id/
    assert_file "app/models/user.rb", /include PasskeyConcern/
    assert_file "app/models/webauthn_credential.rb", /belongs_to :user/
    assert_migration "db/migrate/add_webauthn_id_to_users.rb",
                     /add_column :users, :webauthn_id, :string/,
                     /add_index :users, :webauthn_id, unique: true/
    assert_migration "db/migrate/create_webauthn_credentials.rb",
                     /create_table :webauthn_credentials/,
                     /t\.string :external_id, null: false/,
                     /add_index :webauthn_credentials, :external_id, unique: true/
    assert_file "app/controllers/webauthn_credentials_controller.rb",
                /WebAuthn::Credential\.options_for_create/,
                /WebAuthn::Credential\.from_create/
    assert_file "app/controllers/passkey_sessions_controller.rb",
                /WebAuthn::Credential\.from_get/
    assert_file "app/views/webauthn_credentials/index.html.erb", /t\('\.heading'\)/
    assert_file "app/views/webauthn_credentials/new.html.erb", /navigator\.credentials\.create/
    assert_file "config/routes.rb",
                /resources :webauthn_credentials, only: %i\[ index new create destroy \]/,
                /resource :passkey_session, only: %i\[ create \], controller: "passkey_sessions"/
    assert_file "Gemfile", /gem "webauthn"/
  end

  it "wires passkey options generation into SessionsController#new and adds a sign-in button" do
    run_generator %w[--passkey]

    assert_file "app/controllers/sessions_controller.rb", /WebAuthn::Credential\.options_for_get/
    assert_file "app/views/sessions/new.html.erb",
                /button_tag t\('\.links\.passkey'\)/,
                /navigator\.credentials\.get/
    assert_file "config/locales/authentication.en.yml", /passkey: Sign in with a passkey/
  end

  it "links to passkey management from the account page when registerable is enabled" do
    run_generator %w[--passkey]

    assert_file "app/views/registrations/edit.html.erb", /link_to t\('\.links\.passkeys'\), webauthn_credentials_path/
  end

  it "does not reference passkeys on the account page when passkey is skipped" do
    run_generator

    assert_file "app/views/registrations/edit.html.erb" do |view|
      expect(view).not_to include("passkey")
    end
  end

  it "hooks the other features into the passkey sign-in flow" do
    run_generator %w[--passkey]

    assert_file "app/controllers/passkey_sessions_controller.rb",
                /user\.locked\?/,
                /user\.confirmed\?/,
                /user\.invitation_pending\?/,
                /user\.reset_failed_attempts!/,
                /record_authentication_attempt\(user, success: true\)/
  end

  it "renders a plain sign-in flow when the other features are skipped" do
    run_generator %w[--passkey --skip-lockable --skip-confirmable --skip-invitable --skip-trackable]

    assert_file "app/controllers/passkey_sessions_controller.rb" do |controller|
      expect(controller).not_to include("locked?")
      expect(controller).not_to include("confirmed?")
      expect(controller).not_to include("invitation_pending?")
      expect(controller).not_to include("record_authentication_attempt")
    end
  end
end
