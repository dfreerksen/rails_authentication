# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      module Timeoutable
        private
          # No migration: inactivity is measured against sessions.updated_at, which the
          # base generator's sessions table already has.
          def generate_timeoutable
            template "app/models/concerns/timeoutable_concern.rb"
            include_concern_in_user "TimeoutableConcern"
          end
      end
    end
  end
end
