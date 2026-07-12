# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      module Invitable
        private
          def generate_invitable
            template "app/models/concerns/invitable_concern.rb"
            include_concern_in_user "InvitableConcern"
            migration_template "db/migrate/add_invitable_to_users.rb", "db/migrate/add_invitable_to_users.rb"
            template "app/controllers/invitations_controller.rb"
            template "app/views/invitations/new.html.erb"
            template "app/views/invitations/edit.html.erb"
            route "resources :invitations, only: %i[ new create edit update ], param: :token"

            if defined?(ActionMailer::Railtie)
              template "app/mailers/invitations_mailer.rb"
              template "app/views/invitations_mailer/invitation_instructions.html.erb"
              template "app/views/invitations_mailer/invitation_instructions.text.erb"
            end
          end
      end
    end
  end
end
