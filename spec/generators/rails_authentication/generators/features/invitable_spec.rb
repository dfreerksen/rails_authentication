# frozen_string_literal: true

RSpec.describe RailsAuthentication::Generators::Features::Invitable, type: :generator do
  it "generates the concern, migration, controller, mailer, views, and route" do
    run_generator

    assert_file "app/models/concerns/invitable_concern.rb",
                /def invite!\(attributes, invited_by: nil\)/,
                /attributes = attributes\.to_h\.symbolize_keys/,
                /user = new\(attributes\)/,
                /def accept_invitation!\(password:, password_confirmation:\)/,
                /belongs_to :invited_by, polymorphic: true, optional: true/,
                /invited_by\.increment!\(:invitations_count\) if invited_by\.respond_to\?\(:invitations_count\)/
    assert_file "app/models/user.rb", /include InvitableConcern/
    assert_migration "db/migrate/add_invitable_to_users.rb",
                     /add_column :users, :invitation_token, :string/,
                     /add_column :users, :invitation_created_at, :datetime/,
                     /add_column :users, :invitation_sent_at, :datetime/,
                     /add_column :users, :invitation_accepted_at, :datetime/,
                     /add_column :users, :invitations_count, :integer, default: 0/,
                     /add_reference :users, :invited_by, polymorphic: true/,
                     /add_index :users, :invitation_token, unique: true/
    assert_file "app/controllers/invitations_controller.rb",
                /require_unauthenticated_access only: %i\[ edit update \]/,
                /User\.invite!\(invitation_params, invited_by: Current\.user\)/,
                /def invitation_params\n    params\.permit\(:email_address\)\n  end/
    assert_file "app/mailers/invitations_mailer.rb", /def invitation_instructions\(user\)/
    assert_file "app/views/invitations/new.html.erb", /form_with url: invitations_path/
    assert_file "app/views/invitations/edit.html.erb", /invitation_path\(params\[:token\]\)/
    assert_file "app/views/invitations_mailer/invitation_instructions.html.erb",
                /edit_invitation_url\(@user\.invitation_token\)/
    assert_file "config/routes.rb", /resources :invitations, only: %i\[ new create edit update \], param: :token/
  end

  it "confirms the user on acceptance when confirmable is enabled" do
    run_generator

    assert_file "app/models/concerns/invitable_concern.rb", /self\.confirmed_at \|\|= Time\.current/
  end

  it "does not reference confirmation when confirmable is skipped" do
    run_generator %w[--skip-confirmable]

    assert_file "app/models/concerns/invitable_concern.rb" do |concern|
      expect(concern).not_to include("confirmed_at")
    end
  end

  it "blocks sign-in for a pending invitee via the sessions controller" do
    run_generator

    assert_file "app/controllers/sessions_controller.rb", /elsif user\.invitation_pending\?/
  end

  it "is skipped with --skip-invitable" do
    run_generator %w[--skip-invitable]

    assert_no_file "app/models/concerns/invitable_concern.rb"
    assert_no_migration "db/migrate/add_invitable_to_users.rb"
    assert_no_file "app/controllers/invitations_controller.rb"
    assert_file "app/controllers/sessions_controller.rb" do |controller|
      expect(controller).not_to include("invitation_pending?")
    end
  end

  it "scopes pending invitations the way invitation_pending? sees them" do
    run_generator

    assert_file "app/models/concerns/invitable_concern.rb" do |concern|
      expect(concern).to include(
        "scope :pending, -> { where.not(invitation_token: nil).where(invitation_accepted_at: nil) }"
      )
      expect(concern).to include(
        "scope :not_pending, -> { where(invitation_token: nil).or(where.not(invitation_accepted_at: nil)) }"
      )
    end
  end
end
