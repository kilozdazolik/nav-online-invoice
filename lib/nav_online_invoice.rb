# frozen_string_literal: true

require "bigdecimal"
require "date"
require "net/http"
require "nokogiri"
require "openssl"
require "securerandom"
require "stringio"
require "time"
require "uri"
require "zlib"

require_relative "nav_online_invoice/version"
require_relative "nav_online_invoice/redacted"
require_relative "nav_online_invoice/technical_validation_message"
require_relative "nav_online_invoice/errors"
require_relative "nav_online_invoice/namespaces"
require_relative "nav_online_invoice/xml_reader"
require_relative "nav_online_invoice/schema_validator"
require_relative "nav_online_invoice/crypto"
require_relative "nav_online_invoice/request_id"
require_relative "nav_online_invoice/tax_number"
require_relative "nav_online_invoice/params"
require_relative "nav_online_invoice/payload"
require_relative "nav_online_invoice/monotonic"
require_relative "nav_online_invoice/retry"
require_relative "nav_online_invoice/throttle"
require_relative "nav_online_invoice/redactor"
require_relative "nav_online_invoice/configuration"
require_relative "nav_online_invoice/request_builder"
require_relative "nav_online_invoice/transport"
require_relative "nav_online_invoice/response_parser"
require_relative "nav_online_invoice/page"
require_relative "nav_online_invoice/paging"
require_relative "nav_online_invoice/address"
require_relative "nav_online_invoice/taxpayer"
require_relative "nav_online_invoice/taxpayer_result"
require_relative "nav_online_invoice/transaction"
require_relative "nav_online_invoice/business_validation_message"
require_relative "nav_online_invoice/processing_result"
require_relative "nav_online_invoice/transaction_status"
require_relative "nav_online_invoice/audit_data"
require_relative "nav_online_invoice/invoice_data_result"
require_relative "nav_online_invoice/invoice_digest"
require_relative "nav_online_invoice/invoice_reference"
require_relative "nav_online_invoice/invoice_chain_element"
require_relative "nav_online_invoice/exchange_token"
require_relative "nav_online_invoice/electronic_invoice_hash"
require_relative "nav_online_invoice/submission"
require_relative "nav_online_invoice/metric_definition"
require_relative "nav_online_invoice/metric_value"
require_relative "nav_online_invoice/metric"
require_relative "nav_online_invoice/service_metrics"
require_relative "nav_online_invoice/metrics"
require_relative "nav_online_invoice/operations/base"
require_relative "nav_online_invoice/operations/query_taxpayer"
require_relative "nav_online_invoice/operations/query_transaction_list"
require_relative "nav_online_invoice/operations/query_transaction_status"
require_relative "nav_online_invoice/operations/invoice_number_query"
require_relative "nav_online_invoice/operations/query_invoice_check"
require_relative "nav_online_invoice/operations/query_invoice_data"
require_relative "nav_online_invoice/operations/invoice_query_params"
require_relative "nav_online_invoice/operations/query_invoice_digest"
require_relative "nav_online_invoice/operations/query_invoice_chain_digest"
require_relative "nav_online_invoice/operations/token_exchange"
require_relative "nav_online_invoice/operations/manage"
require_relative "nav_online_invoice/operations/manage_invoice"
require_relative "nav_online_invoice/operations/manage_annulment"
require_relative "nav_online_invoice/submission_items"
require_relative "nav_online_invoice/annulment_items"
require_relative "nav_online_invoice/taxpayers"
require_relative "nav_online_invoice/transactions"
require_relative "nav_online_invoice/invoices"
require_relative "nav_online_invoice/client"

# Client for the Hungarian Tax Authority's (NAV) Online Invoice API v3.0.
#
# Each client gets its own configuration, so one application can call the
# Online Invoice API for several companies.
#
# @see https://github.com/nav-gov-hu/Online-Invoice NAV API documentation
module NavOnlineInvoice
  @mutex = Mutex.new

  class << self
    # The logger of every configuration that does not set one, e.g. the Rails logger. Nil by default.
    #
    # @return [Logger, nil]
    attr_accessor :default_logger

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
      raise ArgumentError, "NavOnlineInvoice.configure needs a block" unless block_given?

      builder = Configuration::Builder.new
      yield builder
      configuration = builder.build
      @mutex.synchronize do
        @configuration = configuration
        @client = nil
      end
      configuration
    end

    # The configuration set with {configure}.
    #
    # @return [Configuration]
    # @raise [ConfigurationError] if {configure} has not been called
    def configuration
      @configuration || raise(ConfigurationError, "call NavOnlineInvoice.configure first")
    end

    # A shared client for the configuration set with {configure}.
    #
    # @return [Client]
    def client
      @client || @mutex.synchronize { @client ||= Client.new(configuration) }
    end

    # Forgets the global configuration and client.
    #
    # @api private
    def reset!
      @mutex.synchronize do
        @configuration = nil
        @client = nil
      end
    end
  end
end

require_relative "nav_online_invoice/railtie" if defined?(Rails::Railtie)
