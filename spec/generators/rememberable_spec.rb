# frozen_string_literal: true

RSpec.describe "authentication generator: rememberable", type: :generator do
  it "generates the concern and migration" do
    run_generator

    assert_file "app/models/concerns/rememberable_concern.rb", /def remember_me!/, /def forget_me!/
    assert_file "app/models/user.rb", /include RememberableConcern/
    assert_migration "db/migrate/add_rememberable_to_users.rb", /add_column :users, :remember_created_at, :datetime/
  end

  it "makes cookie permanence conditional on the remember-me checkbox" do
    run_generator

    assert_file "app/views/sessions/new.html.erb", /check_box :remember_me/
    assert_file "app/controllers/sessions_controller.rb", /start_new_session_for user, remember: params\[:remember_me\] == "1"/
    assert_file "app/controllers/concerns/authentication.rb",
      /def start_new_session_for\(user, remember: false\)/,
      /cookies\.signed\.permanent\[:session_id\]/,
      /user\.forget_me!/
  end

  it "is skipped with --skip-rememberable, restoring the always-permanent cookie" do
    run_generator %w[--skip-rememberable]

    assert_no_file "app/models/concerns/rememberable_concern.rb"
    assert_no_migration "db/migrate/add_rememberable_to_users.rb"
    assert_file "app/controllers/concerns/authentication.rb", /def start_new_session_for\(user\)/,
      /cookies\.signed\.permanent\[:session_id\]/
    assert_file "app/views/sessions/new.html.erb" do |view|
      expect(view).not_to include("remember_me")
    end
  end
end
