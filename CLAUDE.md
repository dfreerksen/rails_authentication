# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this gem is

`rails_authentication` extends Rails 8's built-in `bin/rails generate authentication` command to
also install Devise-style features (Confirmable, Recoverable, Registerable, Rememberable,
Trackable, Timeoutable, Validatable, Lockable, Invitable), each opt-out-able via
`--skip-<feature>`, plus two opt-in features: MagicLink (passwordless email sign-in via
`--magic-link`) and Ott (emailed 6-digit one-time code sign-in via `--ott`; replaces the sign-in
form with an email-only form but keeps the password machinery intact). All code is generated into
the host app; the gem has no runtime footprint.

## Commands

- `bundle exec rspec spec/generators` — generator specs (fast; no Rails app boot; the base
  generator invocation is stubbed)
- `bundle exec rake dummy:prepare` (or `bin/prepare_dummy`) — regenerate `spec/dummy` by running
  `rails new` + the real generator; required before request specs, and after any template change
- `bundle exec rspec spec/requests` — request specs exercising the generated code at runtime
  against `spec/dummy`
- `bundle exec rspec spec/generators/lockable_spec.rb:12` — single example by line number
- `bundle exec rake spec` — generator specs only (default task; requests need the dummy first)

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
`install_base_authentication` (invokes Rails core's `rails:authentication` in-process — User/
Session/Current, SessionsController, PasswordsController, Authentication concern, migrations,
routes) → one `install_<feature>` step per feature (each early-returns on its skip flag — or, for
MagicLink/Ott, on the absence of the opt-in flag — and delegates to a module in
`lib/generators/authentication/features/`) → `customize_session_layer`. MagicLink and Ott are
deliberately NOT in `FEATURES` (that constant drives the `--skip-<feature>` options and
`<feature>?` query methods); their `--magic-link`/`--ott` options and `magic_link?`/`ott?` helpers
are declared separately.

Feature helper methods live in included modules deliberately: module methods never trigger Thor's
`method_added` command registration, so only the class's own public methods become generation
steps. Query helpers (`confirmable?` etc.) sit in a `no_commands` block for the same reason.

### Conditional templates over injection

Confirmable, Rememberable, Trackable, Timeoutable, and Lockable all hook the sign-in flow. Rather
than fragile `inject_into_file` edits, `customize_session_layer` overwrites three base-generator
files (`sessions_controller.rb`, `concerns/authentication.rb`, `views/sessions/new.html.erb`) with
templates full of generation-time ERB conditionals (`<% if lockable? %>`), `force: true` — safe
because the base copies were written moments earlier in the same run. Recoverable similarly
overwrites `passwords_controller.rb` + `PasswordsMailer` (DB-backed tokens replace the base
stateless `generates_token_for`). MagicLink's own `magic_links_controller.rb` template carries the
same generation-time conditionals so its sign-in path honors Lockable/Confirmable/Invitable/
Trackable, and the sessions view template links to it behind `<% if magic_link? %>`. Ott's
`otts_controller.rb` does the same; additionally, the sessions view template swaps the password
form for an email-only form posting to `ott_path` behind `<% if ott? %>`, with a runtime
`params[:with_password]` toggle back to the password form (password machinery —
SessionsController#create, Recoverable — stays generated and functional). In view/
mailer templates, `<%%` escapes runtime ERB; plain `<%` is evaluated at generation time.

Every other feature only adds files plus one `include <Feature>Concern` line injected into
`app/models/user.rb`. Migrations use `migration_template` (via
`ActiveRecord::Generators::Migration`). Mailer generation
is guarded by `defined?(ActionMailer::Railtie)`, evaluated in the host app's process.

### Testing layout (two deliberately separate layers)

**Generator specs** (`spec/generators/`) assert on generated file contents.
`spec/support/generator_helpers.rb` is a small stand-in for `Rails::Generators::TestCase` (whose
`run_generator` injects args our generator doesn't declare): it seeds a destination with the
base-generator files the feature steps inject into, stubs `Rails::Generators.invoke`, and mixes in
Rails' `assert_file`/`assert_migration`. Note `assert_file` with a String arg does exact
whole-file comparison — use Regexps.

**Request specs** (`spec/requests/`) exercise the generated code over HTTP against `spec/dummy`, a
real Rails app **produced by the real generator** via `bin/prepare_dummy` (gitignored, never
hand-edited, so it can't drift from the templates; the script passes `--magic-link --ott` so the
opt-in features are exercised too). The dummy boots against this gem's own Gemfile
(`BUNDLE_GEMFILE` is exported by the script; that's why `bcrypt` is in the gem's Gemfile).
`spec/rails_helper.rb` boots it and forces the inline ActiveJob adapter so mailer specs can assert
on `ActionMailer::Base.deliveries`. If a template changes, rerun `rake dummy:prepare` before
trusting request-spec results.
