# frozen_string_literal: true

RSpec.describe "authentication generator: registerable", type: :generator do
  it "generates the controller, views, and route" do
    run_generator

    assert_file "app/controllers/registrations_controller.rb",
      /allow_unauthenticated_access only: %i\[ new create \]/,
      /def destroy/
    assert_file "app/views/registrations/new.html.erb", /form_with url: registration_path/
    assert_file "app/views/registrations/edit.html.erb", /method: :patch/
    assert_file "config/routes.rb", /resource :registration, only: %i\[ new create edit update destroy \]/
  end

  it "sends confirmation instructions on sign-up when confirmable is enabled" do
    run_generator

    assert_file "app/controllers/registrations_controller.rb", /send_confirmation_instructions/ do |controller|
      expect(controller).not_to include("start_new_session_for @user")
    end
  end

  it "signs the user in immediately when confirmable is skipped" do
    run_generator %w[--skip-confirmable]

    assert_file "app/controllers/registrations_controller.rb", /start_new_session_for @user/ do |controller|
      expect(controller).not_to include("send_confirmation_instructions")
    end
  end

  it "is skipped with --skip-registerable" do
    run_generator %w[--skip-registerable]

    assert_no_file "app/controllers/registrations_controller.rb"
    assert_file "config/routes.rb" do |routes|
      expect(routes).not_to include("registration")
    end
    assert_file "app/views/sessions/new.html.erb" do |view|
      expect(view).not_to include("Sign up")
    end
  end
end
