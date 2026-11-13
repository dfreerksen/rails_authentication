# frozen_string_literal: true

RSpec.describe RailsAuthentication::Generators::Features::Validatable, type: :generator do
  it "generates the concern and includes it in User" do
    run_generator

    assert_file "app/models/concerns/validatable_concern.rb",
                /validates authentication_email_column_name, presence: true/,
                /uniqueness: \{ case_sensitive: false \}/,
                /validates :password, length: \{ in: PASSWORD_LENGTH \}, allow_nil: true/
    assert_file "app/models/user.rb", /include ValidatableConcern/
  end

  it "adds password complexity validation" do
    run_generator

    assert_file "app/models/concerns/validatable_concern.rb",
                /PASSWORD_MINIMUM_COMPLEXITY = 2/,
                /validate :password_complexity/,
                /def password_complexity/,
                /def valid_password_complexity\?/
  end

  it "sizes new-password fields from PASSWORD_LENGTH, which is capped at bcrypt's limit" do
    run_generator

    assert_file "app/models/concerns/validatable_concern.rb",
                /PASSWORD_LENGTH = 6\.\.ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED/
    %w[registrations/new registrations/edit passwords/edit invitations/edit].each do |view|
      assert_file "app/views/#{view}.html.erb" do |content|
        expect(content.scan("maxlength: ValidatableConcern::PASSWORD_LENGTH.max").size).to eq(2)
      end
    end
  end

  it "keeps the sign-in field at bcrypt's limit so existing passwords still fit if the policy changes" do
    run_generator

    assert_file "app/views/sessions/new.html.erb",
                /maxlength: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED/
  end

  it "falls back to bcrypt's limit in new-password fields with --skip-validatable" do
    run_generator %w[--skip-validatable]

    assert_file "app/views/registrations/new.html.erb" do |view|
      expect(view).to include("maxlength: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED")
      expect(view).not_to include("ValidatableConcern")
    end
  end

  it "is skipped with --skip-validatable" do
    run_generator %w[--skip-validatable]

    assert_no_file "app/models/concerns/validatable_concern.rb"
    assert_file "app/models/user.rb" do |user|
      expect(user).not_to include("ValidatableConcern")
    end
  end

  it "leaves blank-password checks to the flows that set a password (Recoverable, Invitable)" do
    run_generator

    assert_file "app/models/concerns/validatable_concern.rb" do |concern|
      expect(concern).not_to include("presence: true, on:")
    end
  end
end
