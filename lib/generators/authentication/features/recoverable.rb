# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      module Recoverable
        private
          # Replaces the base generator's stateless generates_token_for password reset
          # with DB-backed, revocable tokens.
          def generate_recoverable
            template "app/models/concerns/recoverable_concern.rb"
            include_concern_in_user "RecoverableConcern"
            migration_template "db/migrate/add_recoverable_to_users.rb", "db/migrate/add_recoverable_to_users.rb"
            template "app/controllers/passwords_controller.rb", force: true

            if defined?(ActionMailer::Railtie)
              template "app/mailers/passwords_mailer.rb", force: true
              template "app/views/passwords_mailer/reset.html.erb", force: true
              template "app/views/passwords_mailer/reset.text.erb", force: true
            end
          end
      end
    end
  end
end
