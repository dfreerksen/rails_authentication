# frozen_string_literal: true

RSpec.describe RailsAuthentication::Generators::Features::Rememberable, type: :generator do
  it "adds remembered_at to sessions, not users" do
    run_generator

    assert_migration "db/migrate/add_rememberable_to_sessions.rb", /add_column :sessions, :remembered_at, :datetime/
    assert_no_migration "db/migrate/add_rememberable_to_users.rb"
    assert_no_file "app/models/concerns/rememberable_concern.rb"
    assert_file "app/models/user.rb" do |user|
      expect(user).not_to include("RememberableConcern")
    end
    assert_file "app/models/session.rb", /def remembered\?\n    remembered_at\.present\?\n  end/
  end

  it "drops the old per-user column first, only where it exists" do
    run_generator

    assert_migration "db/migrate/remove_remember_created_at_from_users.rb",
                     /remove_column :users, :remember_created_at if column_exists\?\(:users, :remember_created_at\)/,
                     /add_column :users, :remember_created_at, :datetime unless column_exists\?/

    removal = File.basename(migration_file_name("db/migrate/remove_remember_created_at_from_users.rb"))
    addition = File.basename(migration_file_name("db/migrate/add_rememberable_to_sessions.rb"))
    expect(removal).to be < addition
  end

  it "makes cookie permanence conditional on the remember-me checkbox" do
    run_generator

    assert_file "app/views/sessions/new.html.erb", /check_box :remember_me/
    assert_file "app/controllers/sessions_controller.rb",
                /start_new_session_for user, remember: params\[:remember_me\] == "1"/
    assert_file "app/controllers/concerns/authentication.rb",
                /def start_new_session_for\(user, remember: false\)/,
                /remembered_at: \(Time\.current if remember\)/,
                /cookies\.signed\.permanent\[:session_id\]/
  end

  it "remembers per session, never on the user" do
    run_generator

    assert_file "app/controllers/concerns/authentication.rb",
                /def terminate_all_sessions_for\(user\)\n    user\.sessions\.destroy_all/ do |concern|
      expect(concern).to include(<<~RUBY.indent(4))
        if Current.user == user
          Current.session = nil
          cookies.delete(:session_id)
      RUBY
      expect(concern).not_to include("remember_me!")
      expect(concern).not_to include("forget_me!")
    end
  end

  it "is skipped with --skip-rememberable, restoring the always-permanent cookie" do
    run_generator %w[--skip-rememberable]

    assert_no_migration "db/migrate/add_rememberable_to_sessions.rb"
    assert_no_migration "db/migrate/remove_remember_created_at_from_users.rb"
    assert_file "app/controllers/concerns/authentication.rb", /def start_new_session_for\(user\)/,
                /cookies\.signed\.permanent\[:session_id\]/ do |concern|
      expect(concern).not_to include("remembered_at")
    end
    assert_file "app/models/session.rb" do |session|
      expect(session).not_to include("remembered")
    end
    assert_file "app/views/sessions/new.html.erb" do |view|
      expect(view).not_to include("remember_me")
    end
  end
end
