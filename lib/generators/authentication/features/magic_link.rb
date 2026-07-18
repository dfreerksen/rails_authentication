# frozen_string_literal: true

module RailsAuthentication
  module Generators
    module Features
      # Opt-in (--magic-link): magic link sign-in alongside password sign-in.
      # Tokens are DB-backed and single-use, consistent with this gem's
      # Recoverable rework.
      module MagicLink
        private
          def generate_magic_link
            template "app/models/concerns/magic_link_concern.rb"
            include_concern_in_user "MagicLinkConcern"
            migration_template "db/migrate/add_magic_link_to_users.rb", "db/migrate/add_magic_link_to_users.rb"
            template "app/controllers/magic_links_controller.rb"
            template "app/views/magic_links/new.html.erb"
            route "resources :magic_links, only: %i[ new create show ], param: :token"

            if defined?(ActionMailer::Railtie)
              template "app/mailers/magic_links_mailer.rb"
              template "app/views/magic_links_mailer/magic_link.html.erb"
              template "app/views/magic_links_mailer/magic_link.text.erb"
            end
          end
      end
    end
  end
end
