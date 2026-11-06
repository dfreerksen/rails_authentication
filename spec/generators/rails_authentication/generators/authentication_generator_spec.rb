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
