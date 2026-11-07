# frozen_string_literal: true

RSpec.describe RailsAuthentication::Generators::Features::Timeoutable, type: :generator do
  it "generates the concern (no migration needed)" do
    run_generator

    assert_file "app/models/concerns/timeoutable_concern.rb", /TIMEOUT_IN = 30\.minutes/,
                /def timedout\?\(last_activity_at\)/
    assert_file "app/models/user.rb", /include TimeoutableConcern/
    assert_no_migration "db/migrate/add_timeoutable_to_users.rb"
  end

  it "expires and touches sessions in the authentication concern" do
    run_generator

    assert_file "app/controllers/concerns/authentication.rb",
                /if session\.expired\?/,
                /session\.touch/,
                /session\.destroy/
  end

  it "exempts remembered sessions from timeout when rememberable is enabled" do
    run_generator

    assert_file "app/models/session.rb",
                /REMEMBERED_TIMEOUT_IN = 90\.days/,
                /belongs_to :user/,
                /scope :expired, lambda \{/,
                /where\(updated_at: \.\.\.REMEMBERED_TIMEOUT_IN\.ago\)/,
                /\.or\(where\(remembered_at: nil, updated_at: \.\.\.TimeoutableConcern::TIMEOUT_IN\.ago\)\)/,
                /!remembered\? && user\.timedout\?\(updated_at\)/
  end

  it "times out everyone when rememberable is skipped" do
    run_generator %w[--skip-rememberable]

    assert_file "app/models/session.rb",
                /scope :expired, -> \{ where\(updated_at: \.\.\.TimeoutableConcern::TIMEOUT_IN\.ago\) \}/,
                /def expired\?\n    user\.timedout\?\(updated_at\)\n  end/ do |session|
      expect(session).not_to include("REMEMBERED_TIMEOUT_IN")
      expect(session).not_to include("remember")
    end
  end

  it "is skipped with --skip-timeoutable, leaving only the remembered-session cap" do
    run_generator %w[--skip-timeoutable]

    assert_no_file "app/models/concerns/timeoutable_concern.rb"
    assert_file "app/models/session.rb",
                /scope :expired, -> \{ where\(updated_at: \.\.\.REMEMBERED_TIMEOUT_IN\.ago\) \}/ do |session|
      expect(session).not_to include("Timeoutable")
      expect(session).not_to include("timedout?")
    end
  end

  it "leaves sessions unexpired with --skip-timeoutable --skip-rememberable" do
    run_generator %w[--skip-timeoutable --skip-rememberable]

    assert_file "app/models/session.rb" do |session|
      expect(session).to include("belongs_to :user")
      expect(session).not_to include("expired")
    end
    assert_file "app/controllers/concerns/authentication.rb" do |concern|
      expect(concern).not_to include("expired?")
      expect(concern).not_to include("session.touch")
    end
  end
end
