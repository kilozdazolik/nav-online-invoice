# frozen_string_literal: true

module NavOnlineInvoice
  # Base class for all errors raised by this gem.
  #
  # Rescue this to handle any NAV-related failure in one place.
  #
  # @example
  #   begin
  #     client.taxpayers.query("12345678")
  #   rescue NavOnlineInvoice::Error => e
  #     logger.error(e.message)
  #   end
  class Error < StandardError
    # Whether sending the request again later, with a new request ID, can succeed.
    def retryable?
      false
    end
  end

  # The configuration is missing a value or a value has the wrong format.
  class ConfigurationError < Error; end

  # A request or an invoice does not match NAV's XML schema, so nothing was sent.
  #
  # The message leaves out the values the schema rejected, since they can be names, addresses or amounts.
  class SchemaValidationError < Error
    # A value libxml2 quotes in a message: "The value 'Main St 1' is not accepted ..." or
    # "Element 'x': 'abc' is not a valid value ...".
    QUOTED_VALUE = /(?<=value |: )'(?:[^']|'(?! is ))*'(?= is )/
    private_constant :QUOTED_VALUE

    # @return [Array<String>] the full schema validation messages; they can contain personal data, so do not log
    #   them in production
    attr_reader :errors

    # @param errors [Array<String>] the schema validation messages
    def initialize(errors)
      @errors = errors
      shown = errors.first(3).map { |error| error.gsub(QUOTED_VALUE, Redactor::FILTERED) }
      super("XML does not match the NAV schema: #{shown.join("; ")}")
    end
  end

  # The request did not get a usable answer from NAV: timeout, connection error or a non-XML response.
  class TransportError < Error
    # @return [Integer, nil] the HTTP status, if a response arrived
    attr_reader :http_status

    # @param message [String]
    # @param http_status [Integer, nil]
    # @param retryable [Boolean]
    # @param request_sent [Boolean] false only if the connection failed before anything was sent
    def initialize(message, http_status: nil, retryable: true, request_sent: true)
      @http_status = http_status
      @retryable = retryable
      @request_sent = request_sent
      super(message)
    end

    def retryable?
      @retryable
    end

    # Whether the request may have reached NAV. False only if the connection failed before anything was sent.
    def request_sent?
      @request_sent
    end
  end

  # A submission was sent, but no answer arrived, so it is unknown whether NAV received it.
  #
  # Do not send it again blindly: the invoices may already be at NAV. Wait five minutes, then look for the
  # transaction with {Transactions#reconcile} or {Transactions#list} over {#reconcile_window} (spec 1.9.2).
  # Deliberately not a {TransportError}, so a generic retry of transport errors cannot send invoices twice.
  class UnknownOutcomeError < Error
    # Seconds around {#sent_at} to search: NAV suggests a little more than the five minutes it may take to store a
    # submission (spec 1.9.2).
    RECONCILE_WINDOW = (-300..600)

    # The time range to search for a submission sent at `sent_at`.
    #
    # @param sent_at [Time]
    # @return [Range<Time>]
    def self.reconcile_window(sent_at)
      (sent_at + RECONCILE_WINDOW.begin)..(sent_at + RECONCILE_WINDOW.end)
    end

    # @return [String] e.g. "manageInvoice"
    attr_reader :operation

    # @return [String]
    attr_reader :request_id

    # @return [Time] when the request was sent, by NAV's clock as far as it is known (it is worked out from the
    #   exchange token), so a wrong local clock does not move the search window
    attr_reader :sent_at

    # @return [Integer] the number of invoices or annulments in the request
    attr_reader :item_count

    # @param operation [String]
    # @param request_id [String]
    # @param sent_at [Time]
    # @param item_count [Integer]
    def initialize(operation:, request_id:, sent_at:, item_count:)
      @operation = operation
      @request_id = request_id
      @sent_at = sent_at
      @item_count = item_count
      super("NAV #{operation} request_id=#{request_id} got no answer; it may have arrived. Do not resend it: " \
            "after five minutes, look for the transaction (spec 1.9.2)")
    end

    # The time range to search with {Transactions#list}: from five minutes before sending to ten minutes after.
    #
    # @return [Range<Time>]
    def reconcile_window
      self.class.reconcile_window(sent_at)
    end
  end

  # A submission would exceed NAV's size limits, so it was not sent.
  class SubmissionTooLargeError < Error; end

  # NAV sent data that could not be decoded: invoice data that is not valid base64, gzip or UTF-8, or an
  # exchange token that does not decrypt with the exchange key.
  class DecodeError < Error; end

  # NAV answered with an error code.
  #
  # Subclasses group the codes by what the caller can do about them. An unknown code is raised as
  # a plain ApiError.
  class ApiError < Error
    # Kept for code written against 0.2; the class moved to {NavOnlineInvoice::TechnicalValidationMessage}.
    TechnicalValidationMessage = NavOnlineInvoice::TechnicalValidationMessage

    # @return [String, nil] NAV's errorCode, e.g. "FORBIDDEN"
    attr_reader :code
    # @return [String, nil] NAV's own error text
    attr_reader :nav_message
    # @return [String, nil] the ID of the request that failed
    attr_reader :request_id
    # @return [Integer, nil]
    attr_reader :http_status
    # @return [Array<TechnicalValidationMessage>]
    attr_reader :technical_validation_messages

    # Returns the error class for a NAV errorCode.
    #
    # @api private
    # @param code [String, nil]
    # @return [Class<ApiError>]
    def self.for(code)
      return RequestError if code.to_s.start_with?("BAD_QUERY_PARAM_")

      CODES.fetch(code.to_s, ApiError)
    end

    # @param code [String, nil] NAV's errorCode
    # @param nav_message [String, nil] NAV's error text
    # @param request_id [String, nil]
    # @param http_status [Integer, nil]
    # @param technical_validation_messages [Array<TechnicalValidationMessage>]
    def initialize(code:, nav_message: nil, request_id: nil, http_status: nil, technical_validation_messages: [])
      @code = code
      @nav_message = nav_message
      @request_id = request_id
      @http_status = http_status
      @technical_validation_messages = technical_validation_messages
      super(build_message)
    end

    private

    def build_message
      text = [code || "NAV error", nav_message].compact.join(": ")
      request_id ? "#{text} (request_id=#{request_id})" : text
    end
  end

  # The login, password hash or request signature was rejected.
  class AuthenticationError < ApiError; end

  # The technical user has no permission for this operation.
  class PermissionError < ApiError; end

  # The taxpayer or the user's relation to it is not valid at NAV.
  class CustomerError < ApiError; end

  # The request was rejected as invalid. Fix the request before sending it again.
  class RequestError < ApiError; end

  # NAV is under maintenance. Try again later.
  class MaintenanceError < ApiError
    def retryable?
      true
    end
  end

  # The exchange token was rejected or expired before the request was sent. Nothing was stored at NAV;
  # submitting again, which requests a new token, is safe.
  class ExchangeTokenError < ApiError
    def retryable?
      true
    end
  end

  # A temporary NAV failure. Sending the request again with a new request ID can succeed.
  class TemporaryError < ApiError
    def retryable?
      true
    end
  end

  class ApiError
    CODES = {
      AuthenticationError => %w[
        INVALID_SECURITY_USER INVALID_REQUEST_SIGNATURE
        INVALID_PASSWORD_HASH_CRYPTO INVALID_REQUEST_SIGNATURE_HASH_CRYPTO
      ],
      PermissionError => %w[FORBIDDEN],
      CustomerError => %w[
        NOT_REGISTERED_CUSTOMER INVALID_CUSTOMER INVALID_USER_RELATION INVALID_PREDECESSOR_TAX_NUMBER
      ],
      RequestError => %w[
        INVALID_REQUEST INVALID_REQUEST_VERSION INVALID_HEADER_VERSION REQUEST_VERSION_NOT_ALLOWED
        NOT_ALLOWED_EXCEPTION
        INVALID_TIMESTAMP INDEX_NOT_SEQUENTIAL MULTIPLE_QUERY_RESULT_FOUND
        STATUS_QUERY_NOT_ALLOWED
      ],
      ExchangeTokenError => %w[INVALID_EXCHANGE_TOKEN],
      MaintenanceError => %w[MAINTENANCE_MODE],
      TemporaryError => %w[OPERATION_FAILED REQUEST_ID_NOT_UNIQUE]
    }.flat_map { |klass, codes| codes.map { |code| [code, klass] } }.to_h.freeze
    private_constant :CODES
  end
end
