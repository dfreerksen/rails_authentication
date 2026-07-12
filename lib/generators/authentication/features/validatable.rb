# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      module Validatable
        private
          def generate_validatable
            template "app/models/concerns/validatable_concern.rb"
            include_concern_in_user "ValidatableConcern"
          end
      end
    end
  end
end
