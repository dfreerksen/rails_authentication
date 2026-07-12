# frozen_string_literal: true

RSpec.describe "authentication generator: timeoutable", type: :generator do
  it "generates the concern (no migration needed)" do
    run_generator

    assert_file "app/models/concerns/timeoutable_concern.rb", /TIMEOUT_IN = 30\.minutes/, /def timedout\?\(last_activity_at\)/
    assert_file "app/models/user.rb", /include TimeoutableConcern/
    assert_no_migration "db/migrate/add_timeoutable_to_users.rb"
  end

  it "expires and touches sessions in the authentication concern" do
    run_generator

    assert_file "app/controllers/concerns/authentication.rb",
      /timedout\?\(session\.updated_at\)/,
      /session\.touch/,
      /session\.destroy/
  end

  it "exempts remembered users from timeout when rememberable is enabled" do
    run_generator

    assert_file "app/controllers/concerns/authentication.rb", /!session\.user\.remembered\? && session\.user\.timedout\?/
  end

  it "times out everyone when rememberable is skipped" do
    run_generator %w[--skip-rememberable]

    assert_file "app/controllers/concerns/authentication.rb", /if session\.user\.timedout\?\(session\.updated_at\)/
  end

  it "is skipped with --skip-timeoutable" do
    run_generator %w[--skip-timeoutable]

    assert_no_file "app/models/concerns/timeoutable_concern.rb"
    assert_file "app/controllers/concerns/authentication.rb" do |concern|
      expect(concern).not_to include("timedout?")
      expect(concern).not_to include("session.touch")
    end
  end
end
