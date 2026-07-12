# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      module Trackable
        private
          def generate_trackable
            template "app/models/concerns/trackable_concern.rb"
            include_concern_in_user "TrackableConcern"
            template "app/models/user_auth.rb"
            migration_template "db/migrate/create_user_auths.rb", "db/migrate/create_user_auths.rb"
          end
      end
    end
  end
end
