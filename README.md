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
| **Invitable** | Invite users by email; they accept by choosing their own password |

Everything is **generated into your app** as plain, readable code — controllers, views, mailers,
migrations, and one model concern per feature. There is no runtime dependency on this gem: after
generating, the code is yours to edit.

This gem is meant to be installed temporarily. Install it long enough to run the generators and uninstall it after. If you keep it installed, keep it in the `development` group.

## Installation

Requires Rails >= 8.0 and, for the email-driven features (Confirmable, Recoverable, Lockable,
Invitable), Action Mailer.

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

Each feature adds a single `include <Feature>Concern` line to `app/models/user.rb`; all of its
model behavior lives in `app/models/concerns/<feature>_concern.rb`. Tunables are plain constants in
the generated concerns — e.g. `TimeoutableConcern::TIMEOUT_IN`, `LockableConcern::MAXIMUM_ATTEMPTS`,
`LockableConcern::UNLOCK_IN`, `ConfirmableConcern::CONFIRMATION_TOKEN_EXPIRES_IN`,
`ValidatableConcern::PASSWORD_LENGTH`, `ValidatableConcern::PASSWORD_MINIMUM_COMPLEXITY` — edit them
there. Concerns keep the model clean.

### Generated routes

```
resource  :registration, only: %i[ new create edit update destroy ]
resources :confirmations, only: %i[ new create show ], param: :token
resources :unlocks,       only: %i[ new create show ], param: :token
resources :invitations,   only: %i[ new create edit update ], param: :token
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

- OTP (Google Authenticator)
- Passwordless (code emailed)

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
