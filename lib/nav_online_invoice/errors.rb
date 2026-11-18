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

  # The outgoing request does not match NAV's XML schema, so it was not sent.
  class SchemaValidationError < Error
    # @return [Array<String>] the schema validation messages
    attr_reader :errors

    # @param errors [Array<String>] the schema validation messages
    def initialize(errors)
      @errors = errors
      super("Request does not match the NAV schema: #{errors.first(3).join("; ")}")
    end
  end

  # The request did not get a usable answer from NAV: timeout, connection error or a non-XML response.
  class TransportError < Error
    # @return [Integer, nil] the HTTP status, if a response arrived
    attr_reader :http_status

    # @param message [String]
    # @param http_status [Integer, nil]
    # @param retryable [Boolean]
    def initialize(message, http_status: nil, retryable: true)
      @http_status = http_status
      @retryable = retryable
      super(message)
    end

    def retryable?
      @retryable
    end
  end

  # NAV sent data that could not be decoded: invoice data that is not valid base64, gzip or UTF-8, or an
  # exchange token that does not decrypt with the exchange key.
  class DecodeError < Error; end

  # NAV answered with an error code.
  #
  # Subclasses group the codes by what the caller can do about them. An unknown code is raised as
  # a plain ApiError.
  class ApiError < Error
    # One schema violation reported by NAV in a GeneralErrorResponse.
    #
    # @!attribute result_code
    #   @return [Symbol] +:error+ or +:critical+
    # @!attribute error_code
    #   @return [String, nil]
    # @!attribute message
    #   @return [String, nil] the element, its value and the expected value
    TechnicalValidationMessage = Data.define(:result_code, :error_code, :message)

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
      PermissionError => %w[FORBIDDEN NOT_ALLOWED_EXCEPTION],
      CustomerError => %w[
        NOT_REGISTERED_CUSTOMER INVALID_CUSTOMER INVALID_USER_RELATION INVALID_PREDECESSOR_TAX_NUMBER
      ],
      RequestError => %w[
        INVALID_REQUEST INVALID_REQUEST_VERSION INVALID_HEADER_VERSION REQUEST_VERSION_NOT_ALLOWED
        INVALID_TIMESTAMP INDEX_NOT_SEQUENTIAL INVALID_EXCHANGE_TOKEN MULTIPLE_QUERY_RESULT_FOUND
        STATUS_QUERY_NOT_ALLOWED
      ],
      MaintenanceError => %w[MAINTENANCE_MODE],
      TemporaryError => %w[OPERATION_FAILED REQUEST_ID_NOT_UNIQUE]
    }.flat_map { |klass, codes| codes.map { |code| [code, klass] } }.to_h.freeze
    private_constant :CODES
  end
end
