# frozen_string_literal: true

RSpec.describe "authentication generator: trackable", type: :generator do
  it "generates the concern, UserAuth model, and user_auths migration" do
    run_generator

    assert_file "app/models/concerns/trackable_concern.rb", /has_many :user_auths, dependent: :destroy/
    assert_file "app/models/user.rb", /include TrackableConcern/
    assert_file "app/models/user_auth.rb", /belongs_to :user, optional: true/, /def self\.record\(user, request, success:, failure_reason: nil\)/
    assert_migration "db/migrate/create_user_auths.rb",
      /create_table :user_auths/,
      /t\.references :user, foreign_key: true/,
      /t\.string :ip/,
      /t\.string :user_agent/,
      /t\.string :referrer/,
      /t\.boolean :success, default: false, null: false/,
      /t\.string :failure_reason/
  end

  it "records successes and failures in the sessions controller" do
    run_generator

    assert_file "app/controllers/sessions_controller.rb",
      /record_authentication_attempt\(account, success: false, failure_reason: "invalid_credentials"\)/,
      /record_authentication_attempt\(user, success: true\)/,
      /UserAuth\.record/
  end

  it "is skipped with --skip-trackable" do
    run_generator %w[--skip-trackable]

    assert_no_file "app/models/user_auth.rb"
    assert_no_migration "db/migrate/create_user_auths.rb"
    assert_file "app/controllers/sessions_controller.rb" do |controller|
      expect(controller).not_to include("record_authentication_attempt")
    end
  end
end
