# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      module Lockable
        private
          def generate_lockable
            template "app/models/concerns/lockable_concern.rb"
            include_concern_in_user "LockableConcern"
            migration_template "db/migrate/add_lockable_to_users.rb", "db/migrate/add_lockable_to_users.rb"
            template "app/controllers/unlocks_controller.rb"
            template "app/views/unlocks/new.html.erb"
            route "resources :unlocks, only: %i[ new create show ], param: :token"

            if defined?(ActionMailer::Railtie)
              template "app/mailers/unlocks_mailer.rb"
              template "app/views/unlocks_mailer/unlock_instructions.html.erb"
              template "app/views/unlocks_mailer/unlock_instructions.text.erb"
            end
          end
      end
    end
  end
end
