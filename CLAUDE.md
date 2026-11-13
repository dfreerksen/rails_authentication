# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this gem is

`rails_authentication` extends Rails 8's built-in `bin/rails generate authentication` command to
also install Devise-style features (Confirmable, Recoverable, Registerable, Rememberable,
Trackable, Timeoutable, Validatable, Lockable, Invitable), each opt-out-able via
`--skip-<feature>`, plus three opt-in features: MagicLink (passwordless email sign-in via
`--magic-link`), Ott (emailed 6-digit one-time code sign-in via `--ott`; replaces the sign-in form
with an email-only form but keeps the password machinery intact), and Passkey (usernameless
WebAuthn passkey sign-in alongside the password form via `--passkey`; requires the host app to add
the `webauthn` gem itself). All code is generated into the host app; the gem has no runtime
footprint.

## Commands

- `bundle exec rspec spec/generators` — generator specs (fast; no Rails app boot; the base
  generator invocation is stubbed)
- `bundle exec rake dummy:prepare` (or `bin/prepare_dummy`) — regenerate `spec/dummy` by running
  `rails new` + the real generator; required before request specs, and after any template change
- `bundle exec rspec spec/requests` — request specs exercising the generated code at runtime
  against `spec/dummy`
- `bundle exec rspec spec/generators/rails_authentication/generators/features/lockable_spec.rb:12` — single example by line number
- `bundle exec rake spec:i18n` — i18n-tasks checks (missing/unused keys, normalized, interpolations)
  on the generated `spec/dummy/config/locales/authentication.en.yml`, configured by
  `config/i18n-tasks.yml`; needs the dummy first. Fix failures in the
  `authentication.en.yml.tt` template (keys sorted, i18n-tasks' YAML quoting), never in spec/dummy
- `bundle exec rake spec` — generator specs only (default task; requests and i18n need the dummy first)
- `bundle exec rubocop` — lint (config in `.rubocop.yml`)

### Testing against multiple Rails and json versions

CI (`.github/workflows/ci.yml`) runs the full suite once per cell of a Rails × json matrix,
driven by `appraisal2` (see the `Appraisals` file; everything not pinned there comes from the
root `Gemfile`). The matrix is currently `rails-8.0-json-2`, `rails-8.1-json-2`,
`rails-8.0-json-3`, `rails-8.1-json-3`. The json axis exists because of a real, current
incompatibility, not for its own sake — see below. Locally:

- `bundle exec appraisal generate-install` — (re)generate `gemfiles/*.gemfile` from `Appraisals`
  and install each; run after editing `Appraisals` or the root `Gemfile`
- `bundle exec appraisal rails-8.0-json-2 rake spec:generators` /
  `... rake dummy:prepare` / `... rake spec:requests` / `... rake spec:i18n` — run one
  appraisal's slice; see
  `bin/appraisal` for the full sequence across every appraisal

`gemfiles/*.gemfile` are committed; `gemfiles/*.gemfile.lock` are gitignored (same reasoning as
the root `Gemfile.lock`: this is a gem, not an app, so it shouldn't pin its consumers'/CI's
dependency resolution beyond the version lines declared in `Appraisals`) — each CI run re-resolves
within the pinned line, which is what caught the Rails-8.1-era `to_json` arity regression CI hit
on 2026-09-11 (see git log around that date for the incident and fix).

Generator specs (`spec/generators/`) write to a scratch directory that's namespaced by process id
(`tmp/destination-#{Process.pid}` in `spec/support/generator_helpers.rb`), not a fixed
`tmp/destination` — appraisal runs happening close together (or a leftover process from an
interrupted run) previously collided on that fixed path, with Thor prompting to overwrite a file
or migration a *different* process had written. Don't change it back to a fixed path.

CI installs only the one gemfile each matrix job actually needs (`bundle exec appraisal
${{ matrix.appraisal }} bundle install`), not `appraisal generate-install`. That command installs
*every* gemfile in `Appraisals` into the job's single shared `vendor/bundle`, and when two
appraisals depend on the identical version of a gem with a native extension (both json-3
appraisals resolve the same `json` version), installing it a second time into the same
`vendor/bundle` collides mid-build — seen in CI as either `Directory not empty @
rb_file_s_rename` or a missing `extconf.rb` on the second attempt, depending on which build step
the two installs raced on. This isn't an upstream json bug; it only shows up when a single job
installs more than one gemfile. `bin/appraisal` (the local one-shot runner across every appraisal)
still uses `generate-install` and can hit the same collision locally if two appraisals share an
exact gem version — if that happens, install appraisals one at a time instead
(`bundle exec appraisal <name> bundle install`).

### The json 2 vs json 3 incompatibility

`json` 3.0 (still an RC as of 2026-09, see https://bugs.ruby-lang.org/issues/22241) removed the
`quirks_mode:` keyword and made `JSON.generate`/`JSON.parse`'s second argument keyword-only.
Rails' `ActiveSupport::JSON` still calls both with `quirks_mode: true` positionally, so every
cookie/session read or write throws `ArgumentError` under json 3 — not a bug in this gem or in
host apps, an upstream Rails/json incompatibility that isn't resolved yet. `bin/prepare_dummy`
writes `spec/dummy/config/initializers/json_quirks_mode_compat.rb`, which prepends a shim onto
`JSON.generate`/`.parse` that strips `quirks_mode` and re-passes remaining options via `**opts`
(so it works whether the resolved `JSON.parse` still takes a positional options hash, json 2.x,
or keywords only, json 3.x). It no-ops under json 2.x (`Gem::Version.new(::JSON::VERSION) >=
Gem::Version.new("3.0")` gates it) and is safe to delete once Rails or json fixes this upstream.

## Architecture

### The namespace trick (load-bearing)

Rails resolves `bin/rails generate authentication` via `find_by_namespace("authentication")`,
checking `authentication:authentication` → `rails:authentication` → `authentication` in that
order. This gem's generator declares `namespace "authentication:authentication"` explicitly
([authentication_generator.rb](lib/generators/authentication/authentication_generator.rb)), which
is checked **before** Rails core's, so the bare `authentication` invocation lands here. The file
must stay at `lib/generators/authentication/authentication_generator.rb` — the lookup globs load
paths by that path. The Ruby module is `RailsAuthentication::Generators`, NOT `Authentication`
(which would yield the same Thor namespace implicitly), because Rails 8's base generator creates a
top-level `Authentication` concern in host apps — squatting that constant breaks any process that
loads both (it broke the request specs before the rename).

### Generator flow

One generator class; Thor runs its public methods in definition order:
`validate_email_attribute` (rejects a bad `--email-attribute` before anything is written) →
`install_base_authentication` (invokes Rails core's `rails:authentication` in-process — User/
Session/Current, SessionsController, PasswordsController, Authentication concern, migrations,
routes) → `rename_email_attribute` → one `install_<feature>` step per feature (each early-returns
on its skip flag — or, for MagicLink/Ott, on the absence of the opt-in flag — and delegates to a
module in `lib/generators/authentication/features/`) → `add_authentication_email_column_name` →
`format_user_model` → `add_user_scopes` → `add_user_availability_predicates` →
`customize_session_layer` → `create_locale_file`. MagicLink and Ott are
deliberately NOT in `FEATURES` (that constant drives the `--skip-<feature>` options and
`<feature>?` query methods); their `--magic-link`/`--ott` options and `magic_link?`/`ott?` helpers
are declared separately.

Feature helper methods live in included modules deliberately: module methods never trigger Thor's
`method_added` command registration, so only the class's own public methods become generation
steps. Query helpers (`confirmable?` etc.) sit in a `no_commands` block for the same reason.

### Conditional templates over injection

Confirmable, Rememberable, Trackable, Timeoutable, and Lockable all hook the sign-in flow. Rather
than fragile `inject_into_file` edits, `customize_session_layer` overwrites four base-generator
files (`models/session.rb`, `sessions_controller.rb`, `concerns/authentication.rb`,
`views/sessions/new.html.erb`) with
templates full of generation-time ERB conditionals (`<% if lockable? %>`), `force: true` — safe
because the base copies were written moments earlier in the same run. Recoverable similarly
overwrites `passwords_controller.rb` + `PasswordsMailer` (DB-backed tokens replace the base
stateless `generates_token_for`) and the base `passwords/new` + `passwords/edit` views (translated
versions of the same forms). MagicLink's own `magic_links_controller.rb` template carries the
same generation-time conditionals so its sign-in path honors Lockable/Confirmable/Invitable/
Trackable, and the sessions view template links to it behind `<% if magic_link? %>`. Ott's
`otts_controller.rb` does the same; additionally, the sessions view template swaps the password
form for an email-only form posting to `ott_path` behind `<% if ott? %>`, with a runtime
`params[:with_password]` toggle back to the password form (password machinery —
SessionsController#create, Recoverable — stays generated and functional). In view/
mailer templates, `<%%` escapes runtime ERB; plain `<%` is evaluated at generation time.

`config/locales/authentication.en.yml.tt` follows the same rule: each feature's translations sit
behind the same `<% if <feature>? -%>` gate as the view or mailer that uses them, so a skipped
feature leaves no keys behind. When a view gains a `t('.…')` call inside a conditional, gate its key
the same way; `authentication_generator_spec.rb` fails on missing *or* unused keys across a set of
feature combinations. Keep the file in i18n-tasks' normalized form (sorted keys, Psych's quoting).

No user-facing English belongs in templates; every string goes through the locale file. Key conventions:

- Views use lazy lookup, `t('.heading')`, which resolves to `<controller>.<action>.heading`.
- Controllers use `t()` with absolute keys, never lazy ones: many messages fire from private
  helpers, `before_action`s and `rate_limit` lambdas, where Rails' lazy lookup (current action) and
  i18n-tasks' (enclosing method) disagree. Flash messages go under `flash.<controller>.<action>`,
  with `notice` for success and named reasons under `alert` for failures
  (`flash.sessions.create.alert.locked`). JSON error messages use
  `json.<controller>.<action>.alert.<reason>`.
  A message that can fire from several actions is repeated under each one. The one exception is
  `flash.authentication.alert.already_signed_in`, fired by the `Authentication` concern's
  `redirect_signed_in_user` across every signed-out flow (and reused as Passkey's JSON error):
  a single shared key, always generated, rather than a copy under each controller and action.
- Mailers use `t('<mailer>.<action>.subject')`.
- Model validations use `errors.add(:attribute, :type)` with the text at
  `activerecord.errors.models.user.attributes.<attribute>.<type>`. i18n-tasks can't see that use,
  hence `ignore_unused` in `config/i18n-tasks.yml`; the generator spec maps these `errors.add` calls
  to their keys instead.
- Trackable's `failure_reason` codes and log messages stay in English: they're data and developer
  output, not UI.

`--email-attribute` (default `email_address`) names the email column, but generated code never
spells it out: it reads `User.authentication_email_column_name`, injected by
`add_authentication_email_column_name` as the first thing in `user.rb` (above the concern
includes, because Validatable's `validates` runs at include time; `normalizes` uses it too).
Controllers and views use the `Authentication` concern's `authentication_email_column_name` (a
`helper_method` delegating to User); models and mailers call the User method
(`self[self.class.authentication_email_column_name]`, `attribute_changed?(…)`,
`user[User.authentication_email_column_name]`). Keep it that way in new templates: no
`<%= email_attribute %>` outside the column definitions. Only the columns themselves are
generation-time: Reconfirmable's `unconfirmed_email_attribute` column, and the base generator's
`create_users` migration, fixtures, and tests, plus the passwords controller/view/mailer that
survive `--skip-recoverable`. `rename_email_attribute` renames those base files with a
word-boundary `gsub_file` right after the base invocation; a new base file that names
`email_address` belongs in `base_files_with_email_attribute`. Names that merely mention email (the
`:ott_email` session key, the `%{email}` interpolation, `postpone_email_change`) are fixed. The
generator spec fails if `email_address` appears anywhere in the output under
`--email-attribute=email`.

`password_maxlength` (in the generator's `no_commands` block) returns Ruby *source* for the
generated views, not a number: `ValidatableConcern::PASSWORD_LENGTH.max` with Validatable, otherwise
`ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED`. New-password fields use it; the sign-in
field always uses the Rails constant so existing passwords still fit if the policy is lowered.

`has_secure_password` treats a blank password as "unchanged" (no error, old digest kept), so each
flow that *sets* a password validates presence in its own context: Recoverable's
`on: :password_reset` (`PasswordsController#update` saves with that context) and Invitable's
`on: :invitation_acceptance` (`accept_invitation!`). Separate contexts, not a shared one, so enabling
both never doubles the error. Registration editing deliberately keeps ignoring a blank password.

Invitable's `User.invite!(attributes, invited_by: nil)` takes an attributes hash (not a bare email
address) so host apps can require extra fields; `InvitationsController#create` passes
`invitation_params` (`params.permit(authentication_email_column_name)`). The README's "Inviting users" section
documents the contract — keep it in sync with the concern.

Access is declared with three `Authentication` class methods. Sign-in is required by default
(the concern's global `before_action :require_authentication`); `allow_unauthenticated_access`
opens actions to everyone (Rails' own method, unchanged); `require_unauthenticated_access` makes
them signed-out only (it calls `allow_unauthenticated_access` and redirects a signed-in user to
`root_path`, or a 403 JSON error for Passkey); `require_authenticated_access` re-states or
re-imposes sign-in. Every signed-out controller (sessions, registrations, passwords,
confirmations, unlocks, invitations edit/update, magic links, otts, passkey sessions) declares
`require_unauthenticated_access` alone; ConfirmationsController alone pairs it with
`allow_unauthenticated_access only: :show`, because with `--reconfirmable` a signed-in user
confirms an email change through that link. `require_authenticated_access` uses its own
`:enforce_authentication` callback on purpose: re-registering `:require_authentication` with
`only:`/`except:` would replace the global callback and leave the other actions public.
Every sign-in flow redirects to `after_authentication_url` (the stored return-to page, else
`default_after_authentication_url`, `root_url` by default and meant to be overridden in the host's
`ApplicationController`); `redirect_signed_in_user` uses the same default. A new sign-in flow must
redirect to `after_authentication_url`, not a hard-coded path.

`add_user_scopes` injects `User.available` / `User.unavailable` after `has_many :sessions`,
chaining the enabled features' scopes (`confirmed`, `not_locked`, `not_pending`; see
`available_user_scope_chain`) so `available` matches exactly the users the sign-in flows let in. `add_user_availability_predicates`
adds the instance versions after `normalizes authentication_email_column_name` (`available?`, aliased
`active_for_authentication?`, and `unavailable?`), built from the same features in `availability_checks`. Feature scopes must agree with
their instance predicates — `locked`/`not_locked` honor `UNLOCK_IN` like `locked?`, and
`pending`/`not_pending` require an invitation token like `invitation_pending?` (users who
signed up uninvited are never `pending`). A new sign-in check belongs in that chain too.

Every other feature only adds files plus one `include <Feature>Concern` line injected into
`app/models/user.rb`. Rememberable is the exception: "remember me" is per browser, stored as
`sessions.remembered_at` (its migration targets `sessions`) with `Session#remembered?` in the
`session.rb` template; there's no User concern and nothing on `users`. Don't move it back onto
the user: one device's sign-in or sign-out must never un-remember another's session. Migrations use `migration_template` (via
`ActiveRecord::Generators::Migration`). Mailer generation
is guarded by `defined?(ActionMailer::Railtie)`, evaluated in the host app's process.

### Testing layout (deliberately separate layers)

**Generator specs** (`spec/generators/`) assert on generated file contents.
`spec/support/generator_helpers.rb` is a small stand-in for `Rails::Generators::TestCase` (whose
`run_generator` injects args our generator doesn't declare): it seeds a destination with the
base-generator files the feature steps inject into (plus the `create_users` migration and fixtures,
so `--email-attribute`'s renaming is exercised), stubs `Rails::Generators.invoke`, and mixes in
Rails' `assert_file`/`assert_migration`. Note `assert_file` with a String arg does exact
whole-file comparison — use Regexps.

Generator specs live at `spec/generators/rails_authentication/generators/features/<feature>_spec.rb`
and `describe` their `Features::<Feature>` module (`authentication_generator_spec.rb` sits one level
up and describes `AuthenticationGenerator`). The deep path and the constant `describe` are what
`RSpec/DescribeClass` and `RSpec/SpecFilePathFormat` require — keep them in sync when adding a
feature.

**Request specs** (`spec/requests/`) exercise the generated code over HTTP against `spec/dummy`, a
real Rails app **produced by the real generator** via `bin/prepare_dummy` (gitignored, never
hand-edited, so it can't drift from the templates; the script passes `--magic-link --ott
--passkey` so the opt-in features are exercised too, and `--email-attribute=email` so the request
specs use `email`, never `email_address`; the script fails if `email_address` survives anywhere).
The dummy boots against this gem's own Gemfile
(`BUNDLE_GEMFILE` is exported by the script; that's why `bcrypt` is in the gem's Gemfile).
`spec/rails_helper.rb` boots it and forces the inline ActiveJob adapter so mailer specs can assert
on `ActionMailer::Base.deliveries`. If a template changes, rerun `rake dummy:prepare` before
trusting request-spec results.

**i18n checks** (`spec/i18n_spec.rb`, run by `rake spec:i18n`) use i18n-tasks on the dummy's
generated `config/locales/authentication.en.yml`, the all-features output. Because they need the
dummy, they're left out of the default `rake spec`, like the request specs. Feature combinations
the dummy doesn't cover are checked by the locale examples in `authentication_generator_spec.rb`.
