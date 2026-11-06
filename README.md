# rails_authentication

Devise-style features on top of Rails 8's built-in authentication generator.

Rails 8's `bin/rails generate authentication` gives you the essentials: a `User` model with
`has_secure_password`, database-backed sessions, sign-in/sign-out, and a password reset flow. This
gem extends that same command to also install:

| Feature | What it does |
| --- | --- |
| **Confirmable** | Emails confirmation instructions; blocks sign-in until the email address is confirmed |
| **Recoverable** | Password reset with DB-backed, revocable, expiring tokens (replaces the base stateless tokens) |
| **Registerable** | Sign-up, plus account editing and deletion |
| **Rememberable** | "Remember me" checkbox — persistent cookie only when checked |
| **Trackable** | Records every sign-in attempt (success and failure) in a `user_auths` table: IP, user agent, referrer, failure reason |
| **Timeoutable** | Expires sessions after 30 minutes of inactivity |
| **Validatable** | Email format/uniqueness, password length, and password complexity validations |
| **Lockable** | Locks the account after 5 failed attempts; unlock via email or automatically after 1 hour |
| **Invitable** | Invite users by email; blocks sign-in until they accept by choosing their own password |
| **MagicLink** (opt-in) | Passwordless magic link sign-in via email — DB-backed, single-use, expiring tokens |
| **Ott** (opt-in) | Passwordless sign-in via an emailed 6-digit one-time code — replaces the password sign-in form |
| **Passkey** (opt-in) | WebAuthn passkey sign-in alongside the password form — usernameless, no email required |

Everything is **generated into your app** as plain, readable code — controllers, views, mailers,
migrations, and one model concern per feature. There is no runtime dependency on this gem: after
generating, the code is yours to edit.

This gem is meant to be installed temporarily. Install it long enough to run the generators and uninstall it after. If you keep it installed, keep it in the `development` group.

## Installation

Requires Rails >= 8.0 and, for the email-driven features (Confirmable, Recoverable, Lockable,
Invitable, MagicLink, Ott), Action Mailer.

```ruby
# Gemfile
group :development do
  gem "rails_authentication"
end
```

## Usage

```sh
bin/rails generate authentication
bin/rails db:migrate
```

That single command runs Rails' built-in authentication generator first, then layers every feature
on top. Skip any feature you don't want:

```sh
bin/rails generate authentication --skip-invitable --skip-trackable
```

Available flags: `--skip-confirmable`, `--skip-recoverable`, `--skip-registerable`,
`--skip-rememberable`, `--skip-trackable`, `--skip-timeoutable`, `--skip-validatable`,
`--skip-lockable`, `--skip-invitable`, and `--reconfirmable` (Confirmable: postpone email address
changes until the new address is confirmed, via an `unconfirmed_email` column).

MagicLink, Ott, and Passkey are **opt-in** features — they change the sign-in UX, so you have to
ask for them:

```sh
bin/rails generate authentication --magic-link
bin/rails generate authentication --ott
bin/rails generate authentication --passkey
```

MagicLink adds a "Sign in with magic link" link to the sign-in page, leading to an email-only
form. The emailed link signs the user in directly; tokens are DB-backed, single-use, and expire
after 20 minutes (`MagicLinkConcern::MAGIC_LINK_EXPIRES_IN`).

Ott replaces the sign-in form: the user enters only their email address, receives a 6-digit code
(`OttConcern::OTT_CODE_LENGTH`) by email, and enters it on a second screen — one single-digit
input per digit with auto-advance and paste/autofill support (plain inline JavaScript, no
framework required). A "Sign in with password
instead" link (`/session/new?with_password=1`) toggles back to the classic password form at
runtime. Codes are DB-backed, single-use, expire after 10 minutes (`OttConcern::OTT_EXPIRES_IN`),
and are voided after 5 wrong entries (`OttConcern::OTT_MAX_ATTEMPTS`). The password machinery
(SessionsController#create, Recoverable, Registerable) stays generated and functional — only the
sign-in UI changes.

Passkey adds a "Sign in with a passkey" button to the sign-in page (no email field — the
browser's own discoverable-credential picker takes its place) plus an authenticated
`/webauthn_credentials` section where a signed-in user can register and remove passkeys (linked
from the account page when Registerable is enabled). Unlike every other feature here, this one
brings a real runtime dependency: the generator adds `gem "webauthn"` to your Gemfile for you (with
a reminder to run `bundle install`), since ceremony verification is delegated to it. A user can
register any number of passkeys, each stored as its own row in `webauthn_credentials`.

All three flows honor the other enabled features: locked, unconfirmed, or invitation-pending
accounts still can't sign in, and Trackable records the attempt.

Each feature adds a single `include <Feature>Concern` line to `app/models/user.rb`; all of its
model behavior lives in `app/models/concerns/<feature>_concern.rb`. Tunables are plain constants in
the generated concerns — e.g. `TimeoutableConcern::TIMEOUT_IN`, `LockableConcern::MAXIMUM_ATTEMPTS`,
`LockableConcern::UNLOCK_IN`, `ConfirmableConcern::CONFIRMATION_TOKEN_EXPIRES_IN`,
`ValidatableConcern::PASSWORD_LENGTH`, `ValidatableConcern::PASSWORD_MINIMUM_COMPLEXITY`,
`OttConcern::OTT_CODE_LENGTH` — edit them there. Concerns keep the model clean.
`PASSWORD_LENGTH` also sets the `maxlength` of the new-password fields; its upper bound can't
exceed 72, bcrypt's limit (`ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED`).

All user-facing text in the generated code (views, flash messages, passkey error messages, email
subjects, and validation messages) lives in `config/locales/authentication.en.yml`, so you can
reword it or add other locales without touching the code. The file only contains translations for
the features you generated.

### Inviting users

Invitable generates a `User.invite!` class method. It takes a **hash of attributes** for the new
user (not just an email address) plus an optional `invited_by:`:

```ruby
User.invite!({ email_address: "new@example.com" }, invited_by: Current.user)

# Any other attributes your User requires go in the same hash
User.invite!({ email_address: "new@example.com", name: "Ada Lovelace" }, invited_by: Current.user)
```

`invite!` accepts symbol or string keys, or permitted `ActionController::Parameters`. It
returns the user either way, so check `persisted?` and `errors` to see whether it worked.

- **New email address**: the user is built from the attributes and gets a random temporary
  password, a fresh invitation token, and `invited_by`, then is saved. On success the invitation
  email is sent and the inviter's `invitations_count` goes up. On a validation failure it returns
  the unsaved user with `errors` and sends nothing.
- **Existing pending invitee**: the token is refreshed and the invitation re-sent. The other
  attributes are ignored.
- **Existing user who isn't a pending invitee**: the user is returned untouched, the other
  attributes are ignored, and no email is sent.

Any `password` in the hash is overwritten with the temporary one, because invitees choose their
own password when they accept. Everything else is mass-assigned, so pass only attributes you've
permitted. Never pass raw `params`.

**Upgrading from the email-only signature.** Earlier versions took the email address as a string,
`User.invite!(email_address, invited_by: ...)`. That form no longer works, so wrap the address in
a hash: `User.invite!({ email_address: email_address }, invited_by: ...)`.

**Requiring more than an email address.** The generated `InvitationsController` passes
`invitation_params` (`params.permit(:email_address)`) to `invite!`. To collect more fields, add
them in three places: the `permit` list, the inputs in `app/views/invitations/new.html.erb`, and
the validations on your model:

```ruby
# app/controllers/invitations_controller.rb
def invitation_params
  params.permit(:email_address, :name)
end
```

### Generated routes

```ruby
resource  :registration, only: %i[ new create edit update destroy ]
resources :confirmations, only: %i[ new create show ], param: :token
resources :unlocks,       only: %i[ new create show ], param: :token
resources :invitations,   only: %i[ new create edit update ], param: :token
resources :magic_links,   only: %i[ new create show ], param: :token   # with --magic-link
resource  :ott,           only: %i[ create edit update ]               # with --ott
resources :webauthn_credentials, only: %i[ index new create destroy ]  # with --passkey
resource  :passkey_session, only: %i[ create ]                         # with --passkey
resource  :session                      # from the base generator
resources :passwords, param: :token     # from the base generator
```

### Notes

- **Existing users + Confirmable**: sign-in requires `confirmed_at`, so backfill it when adding
  Confirmable to an app with existing users:
  `User.update_all(confirmed_at: Time.current)`.
- **Recoverable** replaces the base generator's `PasswordsController`/`PasswordsMailer` (which use
  stateless signed tokens) with DB-token versions, and its password pages with translated ones. If
  you `--skip-recoverable`, the base flow is left untouched, including Rails' English-only password
  pages and messages.
- The generator overwrites the base generator's `SessionsController`, `Authentication` concern, and
  sessions view with versions tailored to the features you selected. Run the generator once, up
  front — re-running it after you've customized those files will prompt to overwrite them.

## Development

```sh
bundle install
bundle exec rake spec:generators   # generator specs (fast, no app boot)
bundle exec rake dummy:prepare     # build spec/dummy by running the real generator
bundle exec rake spec:requests     # request specs against spec/dummy
bundle exec rake spec:i18n         # i18n-tasks checks on spec/dummy's generated locale file
bundle exec rspec spec/generators/rails_authentication/generators/features/lockable_spec.rb:12   # a single example
bundle exec rubocop                # lint
```

`spec/dummy` is generated (and gitignored), never hand-maintained, so the request specs always
exercise exactly what the templates produce. The i18n checks (configured in `config/i18n-tasks.yml`)
run against the same generated app, so fix any failures in
`lib/generators/authentication/templates/config/locales/authentication.en.yml.tt`, not in
`spec/dummy`.

To run the app using the dummy app generated in `spec/dummy`, run `bin/dev`

## Appraisal

Install Appraisal dependencies or when a new Appraisal is added, generate the .gemfile

```sh
bundle exec appraisal generate-install
```

Run tests with Appraisal

```sh
bin/appraisal
```

Run a specific Appraisal test

```sh
# rails-8.0-json-2
bundle exec appraisal rails-8.0-json-2 rake spec:generators
bundle exec appraisal rails-8.0-json-2 rake dummy:prepare
bundle exec appraisal rails-8.0-json-2 rake spec:requests
bundle exec appraisal rails-8.0-json-2 rake spec:i18n
# rails-8.0-json-3
bundle exec appraisal rails-8.0-json-3 rake spec:generators
bundle exec appraisal rails-8.0-json-3 rake dummy:prepare
bundle exec appraisal rails-8.0-json-3 rake spec:requests
bundle exec appraisal rails-8.0-json-3 rake spec:i18n
# rails-8.1-json-2
bundle exec appraisal rails-8.1-json-2 rake spec:generators
bundle exec appraisal rails-8.1-json-2 rake dummy:prepare
bundle exec appraisal rails-8.1-json-2 rake spec:requests
bundle exec appraisal rails-8.1-json-2 rake spec:i18n
# rails-8.1-json-3
bundle exec appraisal rails-8.1-json-3 rake spec:generators
bundle exec appraisal rails-8.1-json-3 rake dummy:prepare
bundle exec appraisal rails-8.1-json-3 rake spec:requests
bundle exec appraisal rails-8.1-json-3 rake spec:i18n
```

## json 3.0 gem compatibility

`json` 3.0 gem removed the `quirks_mode:` keyword and made `JSON.generate`/`JSON.parse`'s second argument keyword-only. Rails' `ActiveSupport::JSON` still calls both with `quirks_mode: true` positionally, so every
cookie/session read or write throws `ArgumentError` under json 3. `bin/prepare_dummy`
writes `spec/dummy/config/initializers/json_quirks_mode_compat.rb`, which prepends a shim onto
`JSON.generate`/`.parse` that strips `quirks_mode` and re-passes remaining options via `**opts`
(so it works whether the resolved `JSON.parse` still takes a positional options hash, json 2.x,
or keywords only, json 3.x). It no-ops under json 2.x (`Gem::Version.new(::JSON::VERSION) >=
Gem::Version.new("3.0")` gates it) and is safe to delete once Rails or json fixes this upstream.

## License

MIT
