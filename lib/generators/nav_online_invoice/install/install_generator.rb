# frozen_string_literal: true

require "rails/generators"

module NavOnlineInvoice
  # Rails generators of the gem.
  module Generators
    # `rails generate nav_online_invoice:install`: creates config/initializers/nav_online_invoice.rb.
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates config/initializers/nav_online_invoice.rb with the settings NAV needs."

      # Writes the initializer; asks before replacing an existing one.
      def create_initializer
        template "nav_online_invoice.rb.tt", "config/initializers/nav_online_invoice.rb"
      end
    end
  end
end
