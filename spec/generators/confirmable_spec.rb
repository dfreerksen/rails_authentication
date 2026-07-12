# frozen_string_literal: true

RSpec.describe "authentication generator: confirmable", type: :generator do
  it "generates the concern, migration, controller, mailer, views, and route" do
    run_generator

    assert_file "app/models/concerns/confirmable_concern.rb",
      /def confirm!/,
      /def find_by_valid_confirmation_token\(token\)/
    assert_file "app/models/user.rb", /include ConfirmableConcern/
    assert_migration "db/migrate/add_confirmable_to_users.rb",
      /add_column :users, :confirmation_token, :string/,
      /add_column :users, :confirmed_at, :datetime/,
      /add_column :users, :confirmation_sent_at, :datetime/,
      /add_index :users, :confirmation_token, unique: true/
    assert_file "app/controllers/confirmations_controller.rb", /def show/
    assert_file "app/mailers/confirmations_mailer.rb", /def confirmation_instructions\(user\)/
    assert_file "app/views/confirmations/new.html.erb", /form_with url: confirmations_path/
    assert_file "app/views/confirmations_mailer/confirmation_instructions.html.erb", /confirmation_url\(@user\.confirmation_token\)/
    assert_file "config/routes.rb", /resources :confirmations, only: %i\[ new create show \], param: :token/
  end

  it "blocks unconfirmed sign-in via the sessions controller" do
    run_generator

    assert_file "app/controllers/sessions_controller.rb", /elsif !user\.confirmed\?/
  end

  it "leaves reconfirmation out by default" do
    run_generator

    assert_migration "db/migrate/add_confirmable_to_users.rb" do |migration|
      expect(migration).not_to include("unconfirmed_email")
    end
    assert_file "app/models/concerns/confirmable_concern.rb" do |concern|
      expect(concern).not_to include("postpone_email_address_change")
    end
  end

  it "supports --reconfirmable" do
    run_generator %w[--reconfirmable]

    assert_migration "db/migrate/add_confirmable_to_users.rb", /add_column :users, :unconfirmed_email, :string/
    assert_file "app/models/concerns/confirmable_concern.rb",
      /before_update :postpone_email_address_change/,
      /self\.email_address = unconfirmed_email if unconfirmed_email\.present\?/
    assert_file "app/mailers/confirmations_mailer.rb", /user\.unconfirmed_email\.presence \|\| user\.email_address/
  end

  it "is skipped with --skip-confirmable" do
    run_generator %w[--skip-confirmable]

    assert_no_file "app/models/concerns/confirmable_concern.rb"
    assert_no_migration "db/migrate/add_confirmable_to_users.rb"
    assert_file "app/controllers/sessions_controller.rb" do |controller|
      expect(controller).not_to include("confirmed?")
    end
  end
end
