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
                /include TrackableConcern/,
                /include TimeoutableConcern/,
                /include LockableConcern/,
                /include InvitableConcern/
  end

  describe "the generated locale file" do
    all_skipped = RailsAuthentication::Generators::AuthenticationGenerator::FEATURES.map { |f| "--skip-#{f}" }
    combinations = {
      "the default feature set" => [],
      "every opt-in feature" => %w[--magic-link --ott --passkey],
      "every feature skipped" => all_skipped
    }
    RailsAuthentication::Generators::AuthenticationGenerator::FEATURES.each do |feature|
      combinations["--skip-#{feature}"] = ["--skip-#{feature}"]
    end
    %w[--magic-link --ott --passkey].each { |flag| combinations["only #{flag}"] = [*all_skipped, flag] }
    combinations["--email-attribute=email"] = %w[--email-attribute=email --magic-link --ott --passkey --reconfirmable]

    combinations.each do |description, args|
      it "has exactly the translations the generated code uses with #{description}" do
        run_generator args

        locale = YAML.load_file(File.join(destination_root, "config/locales/authentication.en.yml"))
        defined_keys = leaf_keys(locale["en"])
        used_keys = view_translation_keys | absolute_translation_keys | validation_message_keys

        expect(missing: used_keys - defined_keys, unused: defined_keys - used_keys).to eq(missing: [], unused: [])
      end
    end

    def leaf_keys(tree, prefix = [])
      tree.flat_map { |key, value| value.is_a?(Hash) ? leaf_keys(value, prefix + [key]) : (prefix + [key]).join(".") }
    end

    # Lazy lookups: app/views/sessions/new.html.erb + t('.links.ott') -> sessions.new.links.ott
    # (partials drop their leading underscore, as Rails does).
    def view_translation_keys
      views_root = File.join(destination_root, "app/views")
      Dir[File.join(views_root, "**/*.erb")].flat_map do |path|
        *dirs, file = path.delete_prefix("#{views_root}/").split("/")
        scope = [*dirs, file.sub(/\..*\z/, "").delete_prefix("_")]
        File.read(path).scan(/\bt\(\s*['"]\.([\w.]+)['"]/).flatten.map { |key| [*scope, key].join(".") }
      end.uniq
    end

    # Rails looks these up itself: errors.add(:password, :complexity) in a User concern reads
    # activerecord.errors.models.user.attributes.password.complexity.
    def validation_message_keys
      Dir[File.join(destination_root, "app/models/concerns/*.rb")].flat_map do |path|
        File.read(path).scan(/errors\.add\(:(\w+), :(\w+)/).map do |attribute, type|
          "activerecord.errors.models.user.attributes.#{attribute}.#{type}"
        end
      end.uniq
    end

    # Absolute lookups in Ruby code: the mailers' t('passwords_mailer.reset.subject') and the
    # controllers' t("flash.sessions.create.alert.locked").
    def absolute_translation_keys
      Dir[File.join(destination_root, "app/**/*.rb")].flat_map do |path|
        File.read(path).scan(/\b(?:I18n\.)?t\(\s*['"](\w[\w.]*)['"]/).flatten
      end.uniq
    end
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

  it "declares access with allow/require_unauthenticated_access and require_authenticated_access" do
    run_generator

    assert_file "app/controllers/concerns/authentication.rb" do |concern|
      expect(concern).to include(<<~RUBY.indent(4))
        def allow_unauthenticated_access(**options)
          skip_before_action :require_authentication, **options
        end
      RUBY
      expect(concern).to include(<<~RUBY.indent(4))
        def require_unauthenticated_access(**options)
          allow_unauthenticated_access(**options)
          before_action :redirect_signed_in_user, **options
        end
      RUBY
      expect(concern).to include(<<~RUBY.indent(4))
        def require_authenticated_access(**options)
          before_action :enforce_authentication, **options
        end
      RUBY
    end
  end

  it "redirects signed-in users to the default, and signed-out page visits back after sign-in" do
    run_generator

    already_signed_in = 't("flash.authentication.alert.already_signed_in")'
    assert_file "app/controllers/concerns/authentication.rb" do |concern|
      expect(concern).to include("return unless authenticated?")
      expect(concern).to include("redirect_to default_after_authentication_url, alert: #{already_signed_in}")
      expect(concern).to include("render json: { error: #{already_signed_in} }, status: :forbidden")
      expect(concern).to include("if request.get? && request.format.html? && !request.xhr?")
      expect(concern).to include("session.delete(:return_to_after_authenticating) || default_after_authentication_url")
      expect(concern).to match(/def default_after_authentication_url\n    root_url\n  end/)
    end
  end

  it "makes every signed-out flow signed-out only" do
    run_generator %w[--magic-link --ott --passkey]

    {
      "sessions" => "only: %i[ new create ]",
      "registrations" => "only: %i[ new create ]",
      "invitations" => "only: %i[ edit update ]",
      "confirmations" => "except: :show",
      "passwords" => nil, "unlocks" => nil, "magic_links" => nil, "otts" => nil, "passkey_sessions" => nil
    }.each do |controller, options|
      assert_file "app/controllers/#{controller}_controller.rb",
                  /^  require_unauthenticated_access#{Regexp.escape(options ? " #{options}" : "")}$/ do |source|
        expected_allows = controller == "confirmations" ? ["  allow_unauthenticated_access only: :show"] : []
        expect(source.scan(/^  allow_unauthenticated_access.*$/)).to eq(expected_allows)
      end
    end
  end

  describe "User.available / User.unavailable" do
    it "chains every enabled sign-in check, in its own block after has_many :sessions" do
      run_generator

      assert_file "app/models/user.rb" do |user|
        expect(user).to include(<<~RUBY.indent(2).chomp)
          has_secure_password
          has_many :sessions, dependent: :destroy

          scope :available, -> { confirmed.not_locked.not_pending }
          scope :unavailable, -> { where.not(id: available) }

          normalizes authentication_email_column_name
        RUBY
      end
    end

    it "adds the matching instance predicates after normalizes" do
      run_generator

      assert_file "app/models/user.rb" do |user|
        expect(user).to include(<<~RUBY.indent(2))
          normalizes authentication_email_column_name, with: ->(e) { e.strip.downcase }

          def available?
            !locked? &&
              confirmed? &&
              !invitation_pending?
          end
          alias active_for_authentication? available?

          def unavailable?
            locked? ||
              !confirmed? ||
              invitation_pending?
          end
        RUBY
      end
    end

    it "leaves out the checks of skipped features" do
      run_generator %w[--skip-lockable]

      assert_file "app/models/user.rb", /scope :available, -> \{ confirmed\.not_pending \}/ do |user|
        expect(user).to include("    confirmed? &&\n      !invitation_pending?\n")
        expect(user).to include("    !confirmed? ||\n      invitation_pending?\n")
        expect(user).not_to include("locked?")
      end
    end

    it "isn't generated when Confirmable, Lockable, and Invitable are all skipped" do
      run_generator %w[--skip-confirmable --skip-lockable --skip-invitable]

      assert_file "app/models/user.rb" do |user|
        expect(user).not_to include("scope :available")
        expect(user).not_to include("scope :unavailable")
        expect(user).not_to include("def available?")
        expect(user).not_to include("def unavailable?")
      end
    end
  end

  it "confirms sign-out with a flash notice" do
    run_generator

    assert_file "app/controllers/sessions_controller.rb",
                /redirect_to new_session_path, status: :see_other, notice: t\("flash\.sessions\.destroy\.notice"\)/
  end

  describe "the session layer with every feature skipped" do
    before do
      run_generator(RailsAuthentication::Generators::AuthenticationGenerator::FEATURES.map { |f| "--skip-#{f}" })
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
        expect(concern).not_to include("expired?")
        expect(concern).not_to include("forget_me!")
      end

      assert_file "app/models/session.rb", /class Session < ApplicationRecord\n  belongs_to :user\nend/

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

  describe "--email-attribute" do
    all_skipped = RailsAuthentication::Generators::AuthenticationGenerator::FEATURES.map { |f| "--skip-#{f}" }
    {
      "the default feature set" => [],
      "every opt-in feature" => %w[--magic-link --ott --passkey --reconfirmable],
      "every feature skipped" => all_skipped
    }.each do |description, args|
      it "leaves no email_address anywhere in the generated output with #{description}" do
        run_generator ["--email-attribute=email", *args]

        offenders = Dir.glob("**/*", base: destination_root).select do |path|
          absolute = File.join(destination_root, path)
          File.file?(absolute) && File.read(absolute).include?("email_address")
        end
        expect(offenders).to be_empty
      end
    end

    it "defines User.authentication_email_column_name above the concerns, which read it when included" do
      run_generator %w[--email-attribute=email]

      assert_file "app/models/user.rb",
                  /\A(?:\ \ \#.*\n|class\ .*\n)+
                   \ \ def\ self\.authentication_email_column_name\ =\ :email\n\n
                   \ \ include\ \w+Concern\n/x,
                  /^  normalizes authentication_email_column_name, with: .*\n\n  def available\?/
    end

    it "defines User.authentication_email_column_name with every feature skipped" do
      run_generator(described_class::FEATURES.map { |f| "--skip-#{f}" })

      assert_file "app/models/user.rb",
                  /^  def self\.authentication_email_column_name = :email_address\n\n  has_secure_password\n/,
                  /^  normalizes authentication_email_column_name, with: /
    end

    it "exposes the column name from the Authentication concern, to controllers and views" do
      run_generator

      assert_file "app/controllers/concerns/authentication.rb",
                  /helper_method :authenticated\?, :current_user, :authentication_email_column_name/,
                  /def authentication_email_column_name\n    User\.authentication_email_column_name\n  end/
    end

    it "renames the column in the base generator's migration and fixtures" do
      run_generator %w[--email-attribute=email]

      assert_migration "db/migrate/create_users.rb",
                       /t\.string :email, null: false/,
                       /add_index :users, :email, unique: true/
      assert_file "test/fixtures/users.yml", /^  email: one@example\.com$/
    end

    it "reads the column name at runtime in generated code instead of naming it" do
      run_generator %w[--email-attribute=login_email --ott]

      assert_file "app/controllers/sessions_controller.rb",
                  /params\.permit\(authentication_email_column_name, :password\)/
      assert_file "app/views/sessions/new.html.erb",
                  /form\.email_field\ authentication_email_column_name,
                   .*value:\ params\[authentication_email_column_name\]/x
      assert_file "app/controllers/otts_controller.rb",
                  /User\.find_by\(authentication_email_column_name => email\)/, /session\[:ott_email\]/
      assert_file "app/mailers/passwords_mailer.rb", /to: user\[User\.authentication_email_column_name\]/
      assert_file "app/models/concerns/validatable_concern.rb",
                  /validates authentication_email_column_name, presence: true/
      assert_file "app/controllers/invitations_controller.rb",
                  /t\("flash\.invitations\.create\.notice", email: user\[authentication_email_column_name\]\)/
      assert_file "config/locales/authentication.en.yml", /notice: Invitation sent to %\{email\}\./

      generated = Dir.glob("{app,config}/**/*", base: destination_root).reject { |path| path == "app/models/user.rb" }
      offenders = generated.select do |path|
        absolute = File.join(destination_root, path)
        File.file?(absolute) && File.read(absolute).include?("login_email")
      end
      expect(offenders).to be_empty
    end

    it "derives Reconfirmable's pending-address column from it" do
      run_generator %w[--email-attribute=login_email --reconfirmable]

      assert_migration "db/migrate/add_confirmable_to_users.rb", /add_column :users, :unconfirmed_login_email, :string/
      assert_file "app/models/concerns/confirmable_concern.rb",
                  /self\[self\.class\.authentication_email_column_name\]\ =
                     \ attribute_in_database\(self\.class\.authentication_email_column_name\)/x,
                  /saved_change_to_unconfirmed_login_email\?/
    end

    it "keeps unconfirmed_email for the default attribute" do
      run_generator %w[--reconfirmable]

      assert_migration "db/migrate/add_confirmable_to_users.rb", /add_column :users, :unconfirmed_email, :string/
      assert_file "app/models/user.rb", /def self\.authentication_email_column_name = :email_address/
    end

    it "rejects a value that isn't a lowercase Ruby identifier, before writing anything" do
      expect { run_generator %w[--email-attribute=E-mail] }.to output(/lowercase Ruby identifier/).to_stderr
      expect(Rails::Generators).not_to have_received(:invoke)
      expect(File).not_to exist(File.join(destination_root, "config/locales/authentication.en.yml"))
    end
  end
end
