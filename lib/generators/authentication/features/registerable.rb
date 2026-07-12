# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      module Registerable
        private
          def generate_registerable
            template "app/controllers/registrations_controller.rb"
            template "app/views/registrations/new.html.erb"
            template "app/views/registrations/edit.html.erb"
            route "resource :registration, only: %i[ new create edit update destroy ]"
          end
      end
    end
  end
end
