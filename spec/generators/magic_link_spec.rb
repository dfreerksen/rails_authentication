# frozen_string_literal: true

RSpec.describe "authentication generator: magic_link", type: :generator do
  it "is left out by default (opt-in)" do
    run_generator

    assert_no_file "app/models/concerns/magic_link_concern.rb"
    assert_no_migration "db/migrate/add_magic_link_to_users.rb"
    assert_no_file "app/controllers/magic_links_controller.rb"
    assert_file "app/models/user.rb" do |user|
      expect(user).not_to include("MagicLinkConcern")
    end
    assert_file "config/routes.rb" do |routes|
      expect(routes).not_to include("magic_links")
    end
    assert_file "app/views/sessions/new.html.erb" do |view|
      expect(view).not_to include("magic link")
    end
  end

  it "generates the concern, migration, controller, mailer, views, and route with --magic-link" do
    run_generator %w[--magic-link]

    assert_file "app/models/concerns/magic_link_concern.rb",
      /def send_magic_link/,
      /def find_by_valid_magic_link_token\(token\)/,
      /def consume_magic_link_token!/
    assert_file "app/models/user.rb", /include MagicLinkConcern/
    assert_migration "db/migrate/add_magic_link_to_users.rb",
      /add_column :users, :magic_link_token, :string/,
      /add_column :users, :magic_link_sent_at, :datetime/,
      /add_index :users, :magic_link_token, unique: true/
    assert_file "app/controllers/magic_links_controller.rb", /def show/
    assert_file "app/mailers/magic_links_mailer.rb", /def magic_link\(user\)/
    assert_file "app/views/magic_links/new.html.erb", /form_with url: magic_links_path/
    assert_file "app/views/magic_links_mailer/magic_link.html.erb", /magic_link_url\(@user\.magic_link_token\)/
    assert_file "app/views/magic_links_mailer/magic_link.text.erb", /magic_link_url\(@user\.magic_link_token\)/
    assert_file "config/routes.rb", /resources :magic_links, only: %i\[ new create show \], param: :token/
  end

  it "links to the magic link page from the sign-in page" do
    run_generator %w[--magic-link]

    assert_file "app/views/sessions/new.html.erb", /link_to "Sign in with magic link", new_magic_link_path/
  end

  it "hooks the other features into the magic link sign-in flow" do
    run_generator %w[--magic-link]

    assert_file "app/controllers/magic_links_controller.rb",
      /elsif user\.locked\?/,
      /elsif !user\.confirmed\?/,
      /elsif user\.invitation_pending\?/,
      /user\.reset_failed_attempts!/,
      /record_authentication_attempt\(user, success: true\)/
  end

  it "renders a plain sign-in flow when the other features are skipped" do
    run_generator %w[--magic-link --skip-lockable --skip-confirmable --skip-invitable --skip-trackable]

    assert_file "app/controllers/magic_links_controller.rb" do |controller|
      expect(controller).not_to include("locked?")
      expect(controller).not_to include("confirmed?")
      expect(controller).not_to include("invitation_pending?")
      expect(controller).not_to include("record_authentication_attempt")
    end
  end
end
