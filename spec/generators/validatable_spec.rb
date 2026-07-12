# frozen_string_literal: true

RSpec.describe "authentication generator: validatable", type: :generator do
  it "generates the concern and includes it in User" do
    run_generator

    assert_file "app/models/concerns/validatable_concern.rb",
      /validates :email_address, presence: true/,
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

  it "is skipped with --skip-validatable" do
    run_generator %w[--skip-validatable]

    assert_no_file "app/models/concerns/validatable_concern.rb"
    assert_file "app/models/user.rb" do |user|
      expect(user).not_to include("ValidatableConcern")
    end
  end
end
