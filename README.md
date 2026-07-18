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

MagicLink and Ott are **opt-in** features — they change the sign-in UX, so you have to ask for
them:

```sh
bin/rails generate authentication --magic-link
bin/rails generate authentication --ott
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

Both flows honor the other enabled features: locked, unconfirmed, or invitation-pending accounts
still can't sign in, and Trackable records the attempt.

Each feature adds a single `include <Feature>Concern` line to `app/models/user.rb`; all of its
model behavior lives in `app/models/concerns/<feature>_concern.rb`. Tunables are plain constants in
the generated concerns — e.g. `TimeoutableConcern::TIMEOUT_IN`, `LockableConcern::MAXIMUM_ATTEMPTS`,
`LockableConcern::UNLOCK_IN`, `ConfirmableConcern::CONFIRMATION_TOKEN_EXPIRES_IN`,
`ValidatableConcern::PASSWORD_LENGTH`, `ValidatableConcern::PASSWORD_MINIMUM_COMPLEXITY`,
`OttConcern::OTT_CODE_LENGTH` — edit them there. Concerns keep the model clean.

### Generated routes

```
resource  :registration, only: %i[ new create edit update destroy ]
resources :confirmations, only: %i[ new create show ], param: :token
resources :unlocks,       only: %i[ new create show ], param: :token
resources :invitations,   only: %i[ new create edit update ], param: :token
resources :magic_links,   only: %i[ new create show ], param: :token   # with --magic-link
resource  :ott,           only: %i[ create edit update ]               # with --ott
resource  :session                      # from the base generator
resources :passwords, param: :token     # from the base generator
```

### Notes

- **Existing users + Confirmable**: sign-in requires `confirmed_at`, so backfill it when adding
  Confirmable to an app with existing users:
  `User.update_all(confirmed_at: Time.current)`.
- **Recoverable** replaces the base generator's `PasswordsController`/`PasswordsMailer` (which use
  stateless signed tokens) with DB-token versions. If you `--skip-recoverable`, the base flow is
  left untouched.
- The generator overwrites the base generator's `SessionsController`, `Authentication` concern, and
  sessions view with versions tailored to the features you selected. Run the generator once, up
  front — re-running it after you've customized those files will prompt to overwrite them.

## Future Plans

- Passkey

## Development

```sh
bundle install
bundle exec rake spec:generators   # generator specs (fast, no app boot)
bundle exec rake dummy:prepare     # build spec/dummy by running the real generator
bundle exec rake spec:requests     # request specs against spec/dummy
bundle exec rspec spec/generators/lockable_spec.rb:12   # a single example
```

`spec/dummy` is generated (and gitignored), never hand-maintained, so the request specs always
exercise exactly what the templates produce.

## License

MIT
