# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      # Opt-in (--ott): one-time token sign-in. The sign-in page becomes an
      # email-only form; a 6-digit code is emailed and entered on a second
      # screen. Codes are DB-backed, single-use, expire after 10 minutes, and
      # are voided after 5 wrong attempts. Password machinery (Recoverable,
      # Registerable, SessionsController#create) is left intact.
      module Ott
        private
          def generate_ott
            template "app/models/concerns/ott_concern.rb"
            include_concern_in_user "OttConcern"
            migration_template "db/migrate/add_ott_to_users.rb", "db/migrate/add_ott_to_users.rb"
            template "app/controllers/otts_controller.rb"
            template "app/views/otts/edit.html.erb"
            route "resource :ott, only: %i[ create edit update ]"

            if defined?(ActionMailer::Railtie)
              template "app/mailers/otts_mailer.rb"
              template "app/views/otts_mailer/ott.html.erb"
              template "app/views/otts_mailer/ott.text.erb"
            end
          end
      end
    end
  end
end
