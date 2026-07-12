# frozen_string_literal: true

RSpec.describe "authentication generator: lockable", type: :generator do
  it "generates the concern, migration, controller, mailer, views, and route" do
    run_generator

    assert_file "app/models/concerns/lockable_concern.rb",
      /MAXIMUM_ATTEMPTS = 5/,
      /UNLOCK_IN = 1\.hour/,
      /def register_failed_attempt!/,
      /def unlock!/
    assert_file "app/models/user.rb", /include LockableConcern/
    assert_migration "db/migrate/add_lockable_to_users.rb",
      /add_column :users, :failed_attempts, :integer, default: 0, null: false/,
      /add_column :users, :unlock_token, :string/,
      /add_column :users, :locked_at, :datetime/,
      /add_index :users, :unlock_token, unique: true/
    assert_file "app/controllers/unlocks_controller.rb", /def show/
    assert_file "app/mailers/unlocks_mailer.rb", /def unlock_instructions\(user\)/
    assert_file "app/views/unlocks/new.html.erb", /form_with url: unlocks_path/
    assert_file "app/views/unlocks_mailer/unlock_instructions.html.erb", /unlock_url\(@user\.unlock_token\)/
    assert_file "config/routes.rb", /resources :unlocks, only: %i\[ new create show \], param: :token/
  end

  it "wires failed-attempt tracking into the sessions controller" do
    run_generator

    assert_file "app/controllers/sessions_controller.rb",
      /account&\.register_failed_attempt!/,
      /elsif user\.locked\?/,
      /user\.reset_failed_attempts!/
  end

  it "is skipped with --skip-lockable" do
    run_generator %w[--skip-lockable]

    assert_no_file "app/models/concerns/lockable_concern.rb"
    assert_no_migration "db/migrate/add_lockable_to_users.rb"
    assert_no_file "app/controllers/unlocks_controller.rb"
    assert_file "app/controllers/sessions_controller.rb" do |controller|
      expect(controller).not_to include("locked?")
      expect(controller).not_to include("register_failed_attempt!")
    end
  end
end
