# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "openssl"
require "securerandom"
require "time"
require "uri"

require_relative "nav_online_invoice/version"
require_relative "nav_online_invoice/errors"
require_relative "nav_online_invoice/schema_validator"
require_relative "nav_online_invoice/crypto"
require_relative "nav_online_invoice/request_id"
require_relative "nav_online_invoice/tax_number"
require_relative "nav_online_invoice/throttle"
require_relative "nav_online_invoice/redactor"
require_relative "nav_online_invoice/configuration"
require_relative "nav_online_invoice/request_builder"
require_relative "nav_online_invoice/transport"
require_relative "nav_online_invoice/response_parser"
require_relative "nav_online_invoice/models"
require_relative "nav_online_invoice/operations/query_taxpayer"
require_relative "nav_online_invoice/client"

# Each client gets its own configuration, so one application can call the
# Online Invoice API for several companies.
#
# @see https://github.com/nav-gov-hu/Online-Invoice NAV API documentation
module NavOnlineInvoice
  @mutex = Mutex.new

  class << self
    # Sets the configuration used by {client}. For several companies, create one {Client} per company instead.
    #
    # @example
    #   NavOnlineInvoice.configure do |config|
    #     config.environment = :production
    #     config.login = credentials.login
    #     # ...
    #   end
    # @yieldparam config [Configuration::Builder]
    # @return [Configuration]
    # @raise [ConfigurationError]
    def configure
      builder = Configuration::Builder.new
      yield builder
      configuration = builder.build
      @mutex.synchronize do
        @configuration = configuration
        @client = nil
      end
      configuration
    end

    # @return [Configuration]
    # @raise [ConfigurationError] if {configure} has not been called
    def configuration
      @configuration || raise(ConfigurationError, "call NavOnlineInvoice.configure first")
    end

    # @return [Client] a client for the global configuration
    def client
      @client || @mutex.synchronize { @client ||= Client.new(configuration) }
    end
  end
end
