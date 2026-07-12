# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      module Rememberable
        private
          def generate_rememberable
            template "app/models/concerns/rememberable_concern.rb"
            include_concern_in_user "RememberableConcern"
            migration_template "db/migrate/add_rememberable_to_users.rb", "db/migrate/add_rememberable_to_users.rb"
          end
      end
    end
  end
end
