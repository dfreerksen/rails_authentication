# frozen_string_literal: true

RSpec.describe "authentication generator: ott", type: :generator do
  it "is left out by default (opt-in)" do
    run_generator

    assert_no_file "app/models/concerns/ott_concern.rb"
    assert_no_migration "db/migrate/add_ott_to_users.rb"
    assert_no_file "app/controllers/otts_controller.rb"
    assert_file "app/models/user.rb" do |user|
      expect(user).not_to include("OttConcern")
    end
    assert_file "config/routes.rb" do |routes|
      expect(routes).not_to include("resource :ott")
    end
    assert_file "app/views/sessions/new.html.erb" do |view|
      expect(view).not_to include("ott_path")
      expect(view).to include("form.password_field :password")
    end
  end

  it "generates the concern, migration, controller, mailer, views, and route with --ott" do
    run_generator %w[--ott]

    assert_file "app/models/concerns/ott_concern.rb",
      /OTT_EXPIRES_IN = 10\.minutes/,
      /OTT_MAX_ATTEMPTS = 5/,
      /OTT_CODE_LENGTH = 6/,
      /def send_ott/,
      /def verify_ott\(code\)/,
      /def consume_ott!/
    assert_file "app/models/user.rb", /include OttConcern/
    assert_migration "db/migrate/add_ott_to_users.rb",
      /add_column :users, :ott_code, :string/,
      /add_column :users, :ott_sent_at, :datetime/,
      /add_column :users, :ott_attempts, :integer, default: 0, null: false/
    assert_file "app/controllers/otts_controller.rb", /def update/
    assert_file "app/mailers/otts_mailer.rb", /def ott\(user\)/
    assert_file "app/views/otts/edit.html.erb",
      /form_with url: ott_path, method: :patch/,
      /form\.hidden_field :code, id: "ott-code"/,
      /OttConcern::OTT_CODE_LENGTH\.times do \|i\|/,
      /getElementById\("ott-code"\)/
    assert_file "app/views/otts_mailer/ott.html.erb", /@user\.ott_code/
    assert_file "app/views/otts_mailer/ott.text.erb", /@user\.ott_code/
    assert_file "config/routes.rb", /resource :ott, only: %i\[ create edit update \]/
  end

  it "replaces the password sign-in form with an email-only form, with a runtime toggle back to password" do
    run_generator %w[--ott]

    assert_file "app/views/sessions/new.html.erb" do |view|
      expect(view).to include("form_with url: ott_path")
      expect(view).to include('form.submit "Email me a sign-in code"')
      expect(view).to include("if params[:with_password].blank?")
      expect(view).to include('link_to "Sign in with password instead", new_session_path(with_password: 1)')
      expect(view).to include('link_to "Sign in with a one-time code instead", new_session_path')
      expect(view).to include("form.password_field :password")
    end
  end

  it "keeps the password machinery intact" do
    run_generator %w[--ott]

    assert_file "app/controllers/sessions_controller.rb", /User\.authenticate_by/
    assert_file "app/controllers/passwords_controller.rb"
  end

  it "hooks the other features into the ott sign-in flow" do
    run_generator %w[--ott]

    assert_file "app/controllers/otts_controller.rb",
      /if user\.locked\?/,
      /unless user\.confirmed\?/,
      /if user\.invitation_pending\?/,
      /user\.reset_failed_attempts!/,
      /record_authentication_attempt\(user, success: true\)/,
      /remember: params\[:remember_me\] == "1"/
  end

  it "renders a plain sign-in flow when the other features are skipped" do
    run_generator %w[--ott --skip-lockable --skip-confirmable --skip-invitable --skip-trackable --skip-rememberable]

    assert_file "app/controllers/otts_controller.rb" do |controller|
      expect(controller).not_to include("locked?")
      expect(controller).not_to include("confirmed?")
      expect(controller).not_to include("invitation_pending?")
      expect(controller).not_to include("record_authentication_attempt")
      expect(controller).not_to include("remember:")
    end
  end
end
