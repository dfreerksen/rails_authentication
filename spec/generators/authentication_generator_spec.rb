# frozen_string_literal: true

RSpec.describe RailsAuthentication::Generators::AuthenticationGenerator, type: :generator do
  it "wins the bare `authentication` namespace over Rails' built-in generator" do
    expect(Rails::Generators.find_by_namespace("authentication")).to eq(described_class)
  end

  it "invokes the base rails:authentication generator" do
    run_generator

    expect(Rails::Generators).to have_received(:invoke)
      .with("rails:authentication", [], hash_including(behavior: :invoke))
  end

  it "exposes current_user as a helper method" do
    run_generator

    assert_file "app/controllers/concerns/authentication.rb",
      /helper_method :authenticated\?, :current_user/,
      /def current_user\n\s*Current\.user\n\s*end/
  end

  it "includes a concern in User for every model-backed feature" do
    run_generator

    assert_file "app/models/user.rb",
      /include ValidatableConcern/,
      /include RecoverableConcern/,
      /include ConfirmableConcern/,
      /include RememberableConcern/,
      /include TrackableConcern/,
      /include TimeoutableConcern/,
      /include LockableConcern/,
      /include InvitableConcern/
  end

  it "honors --skip-<feature> flags" do
    run_generator %w[--skip-confirmable --skip-invitable]

    assert_file "app/models/user.rb" do |user|
      expect(user).not_to include("ConfirmableConcern")
      expect(user).not_to include("InvitableConcern")
      expect(user).to include("include LockableConcern")
    end
    assert_no_file "app/models/concerns/confirmable_concern.rb"
    assert_no_file "app/controllers/invitations_controller.rb"
  end

  describe "the session layer with every feature skipped" do
    before do
      run_generator RailsAuthentication::Generators::AuthenticationGenerator::FEATURES.map { |f| "--skip-#{f}" }
    end

    it "matches the base generator's plain behavior" do
      assert_file "app/controllers/sessions_controller.rb" do |controller|
        expect(controller).not_to include("locked?")
        expect(controller).not_to include("confirmed?")
        expect(controller).not_to include("record_authentication_attempt")
        expect(controller).not_to include("remember")
      end

      assert_file "app/controllers/concerns/authentication.rb",
        /cookies\.signed\.permanent\[:session_id\]/ do |concern|
        expect(concern).not_to include("timedout?")
        expect(concern).not_to include("forget_me!")
      end

      assert_file "app/views/sessions/new.html.erb" do |view|
        expect(view).not_to include("remember_me")
      end
    end

    it "adds no feature concerns to User" do
      assert_file "app/models/user.rb" do |user|
        expect(user.scan(/include \w+Concern/)).to eq([])
      end
    end
  end
end
