# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      module Rememberable
        private

        # "Remember me" is per browser: it's stored on the Session (one row per signed-in
        # browser), not the User, so checking or unchecking it on one device never changes
        # another device's session. No User concern; the behavior lives in the Session
        # model template. Apps generated before the move have users.remember_created_at, so it's
        # dropped first (guarded, so a no-op on new apps), then the sessions column is added.
        def generate_rememberable
          migration_template "db/migrate/remove_remember_created_at_from_users.rb",
                             "db/migrate/remove_remember_created_at_from_users.rb"
          migration_template "db/migrate/add_rememberable_to_sessions.rb", "db/migrate/add_rememberable_to_sessions.rb"
        end
      end
    end
  end
end
