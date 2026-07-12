# frozen_string_literal: true

RSpec.describe "authentication generator: recoverable", type: :generator do
  it "generates the concern, migration, and DB-token passwords controller" do
    run_generator

    assert_file "app/models/concerns/recoverable_concern.rb",
      /def generate_reset_password_token!/,
      /def find_by_valid_reset_password_token\(token\)/
    assert_file "app/models/user.rb", /include RecoverableConcern/
    assert_migration "db/migrate/add_recoverable_to_users.rb",
      /add_column :users, :reset_password_token, :string/,
      /add_column :users, :reset_password_sent_at, :datetime/,
      /add_index :users, :reset_password_token, unique: true/

    assert_file "app/controllers/passwords_controller.rb", /find_by_valid_reset_password_token/ do |controller|
      expect(controller).not_to include("find_by_password_reset_token!") # the base generator's stateless lookup
    end
  end

  it "overwrites the passwords mailer views to use the DB token" do
    run_generator

    assert_file "app/mailers/passwords_mailer.rb", /def reset\(user\)/
    assert_file "app/views/passwords_mailer/reset.html.erb", /edit_password_url\(@user\.reset_password_token\)/
    assert_file "app/views/passwords_mailer/reset.text.erb", /edit_password_url\(@user\.reset_password_token\)/
  end

  it "unlocks the account on password reset when lockable is enabled" do
    run_generator

    assert_file "app/controllers/passwords_controller.rb", /@user\.unlock!/
  end

  it "does not reference unlocking when lockable is skipped" do
    run_generator %w[--skip-lockable]

    assert_file "app/controllers/passwords_controller.rb" do |controller|
      expect(controller).not_to include("unlock!")
    end
  end

  it "is skipped with --skip-recoverable, leaving the base flow alone" do
    run_generator %w[--skip-recoverable]

    assert_no_file "app/models/concerns/recoverable_concern.rb"
    assert_no_migration "db/migrate/add_recoverable_to_users.rb"
    assert_no_file "app/controllers/passwords_controller.rb"
  end
end
