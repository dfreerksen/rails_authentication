# frozen_string_literal: true

require "i18n/tasks"

# Checks spec/dummy/config/locales/authentication.en.yml (the generator's output) against the
# generated app; paths are set in config/i18n-tasks.yml. Needs spec/dummy, like the request specs.
locale_file = File.expand_path("dummy/config/locales/authentication.en.yml", __dir__)
unless File.exist?(locale_file)
  abort "spec/dummy is missing — generate it first with: bundle exec rake dummy:prepare"
end

RSpec.describe I18n do
  let(:i18n) { I18n::Tasks::BaseTask.new }
  let(:missing_keys) { i18n.missing_keys }
  let(:unused_keys) { i18n.unused_keys }
  let(:inconsistent_interpolations) { i18n.inconsistent_interpolations }

  it "does not have missing keys" do
    expect(missing_keys).to be_empty,
                            "Missing #{missing_keys.leaves.count} i18n keys, run `i18n-tasks missing' to show them"
  end

  it "does not have unused keys" do
    expect(unused_keys).to be_empty,
                           "#{unused_keys.leaves.count} unused i18n keys, run `i18n-tasks unused' to show them"
  end

  it "files are normalized" do
    non_normalized = i18n.non_normalized_paths
    error_message = "The following files need to be normalized:\n" \
                    "#{non_normalized.map { |path| "  #{path}" }.join("\n")}\n" \
                    "Fix the key order/quoting in the generator's authentication.en.yml.tt template, " \
                    "then rerun `rake dummy:prepare`"
    expect(non_normalized).to be_empty, error_message
  end

  it "does not have inconsistent interpolations" do
    error_message = "#{inconsistent_interpolations.leaves.count} i18n keys have inconsistent interpolations.\n" \
                    "Run `i18n-tasks check-consistent-interpolations' to show them"
    expect(inconsistent_interpolations).to be_empty, error_message
  end
end
