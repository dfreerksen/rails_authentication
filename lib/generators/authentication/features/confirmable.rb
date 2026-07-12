# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      module Confirmable
        private
          def generate_confirmable
            template "app/models/concerns/confirmable_concern.rb"
            include_concern_in_user "ConfirmableConcern"
            migration_template "db/migrate/add_confirmable_to_users.rb", "db/migrate/add_confirmable_to_users.rb"
            template "app/controllers/confirmations_controller.rb"
            template "app/views/confirmations/new.html.erb"
            route "resources :confirmations, only: %i[ new create show ], param: :token"

            if defined?(ActionMailer::Railtie)
              template "app/mailers/confirmations_mailer.rb"
              template "app/views/confirmations_mailer/confirmation_instructions.html.erb"
              template "app/views/confirmations_mailer/confirmation_instructions.text.erb"
            end
          end
      end
    end
  end
end
