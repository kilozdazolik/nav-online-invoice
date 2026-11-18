# frozen_string_literal: true

module NavOnlineInvoice
  Configuration = Data.define(
    :environment, :login, :password_hash, :signature_key, :exchange_key, :tax_number, :software,
    :logger, :log_payloads, :throttle, :validate_requests, :max_retries, :retry_base_delay,
    :open_timeout, :read_timeout, :write_timeout, :clock, :request_id_generator
  )

  # Settings of one NAV technical user. Immutable; validated when created.
  #
  # Create one per company if the application works for several companies. The plain password is
  # hashed at once and never stored.
  #
  # @example
  #   config = NavOnlineInvoice::Configuration.new(
  #     environment: :test,
  #     login: "technicaluser01",
  #     password: "secret",
  #     signature_key: "...",
  #     tax_number: "12345678",
  #     software: {
  #       id: "HU12345678ABCDE-01",
  #       name: "My invoicing app",
  #       operation: :local_software,
  #       main_version: "1.0",
  #       dev_name: "Example Ltd.",
  #       dev_contact: "dev@example.com"
  #     }
  #   )
  class Configuration
    include Redacted

    ENDPOINTS = {
      test: "https://api-test.onlineszamla.nav.gov.hu/invoiceService/v3/",
      production: "https://api.onlineszamla.nav.gov.hu/invoiceService/v3/"
    }.freeze

    SECRETS = %i[login password_hash signature_key exchange_key].freeze
    private_constant :SECRETS

    DEFAULT_CLOCK = Time.method(:now)
    private_constant :DEFAULT_CLOCK

    # Stands for a logger that was not given, so an explicit nil can still turn logging off.
    DEFAULT_LOGGER = Object.new.freeze
    private_constant :DEFAULT_LOGGER

    # @param environment [Symbol] +:test+ or +:production+; the two need separate technical users
    # @param login [String] the technical user's login
    # @param password [String, nil] the technical user's password (or give +password_hash+)
    # @param password_hash [String, nil] SHA-512 of the password, uppercase hex
    # @param signature_key [String] the technical user's signature key
    # @param exchange_key [String, nil] the exchange key, 16 characters; only needed to submit invoices
    # @param tax_number [String] the technical user's company, 8 or 11 digits
    # @param software [Hash, Software] the software data NAV requires in every request
    # @param logger [Logger, nil] gets one line per request, without any content; {NavOnlineInvoice.default_logger}
    #   if not given, nil for none
    # @param log_payloads [Boolean] also log request and response XML at debug level, with credentials and
    #   invoice data hidden; never in production, since it still contains names, addresses and amounts
    # @param throttle [#wait, nil] limits the request rate; nil turns it off
    # @param validate_requests [Boolean] check each request against NAV's schema before sending
    # @param max_retries [Integer] how often a temporary failure is retried
    # @param retry_base_delay [Numeric] seconds before the first retry; doubles on each retry
    # @param open_timeout [Numeric] seconds to wait for the connection
    # @param read_timeout [Numeric] seconds to wait for the answer
    # @param write_timeout [Numeric] seconds to wait while sending
    # @param clock [#call] returns the current Time; for tests
    # @param request_id_generator [#call] returns a new request ID
    # @raise [ConfigurationError] if a value is empty or has the wrong format
    # @raise [ArgumentError] if a required keyword is missing
    def initialize(environment:, login:, signature_key:, tax_number:, software:, password: nil, password_hash: nil,
                   exchange_key: nil, logger: DEFAULT_LOGGER, log_payloads: false, throttle: Throttle.default,
                   validate_requests: true, max_retries: 2, retry_base_delay: 1.0, open_timeout: 5, read_timeout: 60,
                   write_timeout: 60,
                   clock: DEFAULT_CLOCK, request_id_generator: RequestId)
      super(
        environment: Validation.environment(environment),
        login: Validation.login(login),
        password_hash: Validation.password_hash(password, password_hash),
        signature_key: Validation.required(:signature_key, signature_key),
        exchange_key: Validation.exchange_key(exchange_key),
        tax_number: Validation.tax_number(tax_number),
        software: Validation.software(software),
        logger: logger.equal?(DEFAULT_LOGGER) ? NavOnlineInvoice.default_logger : logger,
        log_payloads: log_payloads ? true : false,
        throttle:,
        validate_requests: validate_requests ? true : false,
        max_retries: Validation.non_negative_integer(:max_retries, max_retries),
        retry_base_delay: Validation.non_negative_number(:retry_base_delay, retry_base_delay),
        open_timeout: Validation.positive_number(:open_timeout, open_timeout),
        read_timeout: Validation.positive_number(:read_timeout, read_timeout),
        write_timeout: Validation.positive_number(:write_timeout, write_timeout),
        clock: Validation.callable(:clock, clock),
        request_id_generator: Validation.callable(:request_id_generator, request_id_generator)
      )
    end

    # The URL of an operation in this environment.
    #
    # @param operation_name [String] e.g. "queryTaxpayer"
    # @return [URI::HTTPS]
    def endpoint(operation_name)
      URI("#{ENDPOINTS.fetch(environment)}#{operation_name}")
    end

    # Returns a copy with the given settings changed.
    #
    # Giving +password+ replaces the stored password hash.
    def with(**changes)
      return super unless changes.key?(:password)

      self.class.new(**members.to_h { |name| [name, public_send(name)] }.except(:password_hash), **changes)
    end

    # Returns the settings with the credentials replaced by [FILTERED].
    def to_h(&block)
      hash = members.to_h { |name| [name, filtered(name)] }
      block ? hash.to_h(&block) : hash
    end

    # Shows the settings with the credentials hidden.
    def inspect
      values = members.map { |name| "#{name}=#{secret?(name) ? Redactor::FILTERED : public_send(name).inspect}" }
      "#<data #{self.class.name} #{values.join(", ")}>"
    end

    private

    def filtered(name)
      secret?(name) ? Redactor::FILTERED : public_send(name)
    end

    def secret?(name)
      SECRETS.include?(name) && !public_send(name).nil?
    end

    # Software data sent in every request.
    #
    # @!attribute id
    #   @return [String] exactly 18 characters of [0-9A-Z-]; NAV suggests country code + tax number + suffix
    # @!attribute operation
    #   @return [Symbol] +:local_software+ or +:online_service+
    # @!attribute dev_contact
    #   @return [String] a working e-mail address of the developer
    Software = Data.define(:id, :name, :operation, :main_version, :dev_name, :dev_contact, :dev_country_code,
                           :dev_tax_number) do
      def initialize(id:, name:, operation:, main_version:, dev_name:, dev_contact:, dev_country_code: nil,
                     dev_tax_number: nil)
        super
      end
    end
  end
end
