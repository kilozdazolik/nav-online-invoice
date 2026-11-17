# frozen_string_literal: true

module NavOnlineInvoice
  # Sends requests to NAV on behalf of one technical user.
  #
  # Thread-safe; create one per configuration and reuse it.
  #
  # @example
  #   client = NavOnlineInvoice::Client.new(config)
  #   client.taxpayers.query("12345678").taxpayer&.name
  class Client
    # @return [Configuration]
    attr_reader :config

    # @return [Taxpayers] tax number lookups
    attr_reader :taxpayers

    # @return [Invoices] invoice queries
    attr_reader :invoices

    # @return [Transactions] queries about submissions
    attr_reader :transactions

    # @param config [Configuration] defaults to the one set with {NavOnlineInvoice.configure}
    def initialize(config = NavOnlineInvoice.configuration)
      @config = config
      @builder = RequestBuilder.new(config)
      @transport = Transport.new(open_timeout: config.open_timeout, read_timeout: config.read_timeout,
                                 write_timeout: config.write_timeout)
      @taxpayers = Taxpayers.new(self)
      @invoices = Invoices.new(self)
      @transactions = Transactions.new(self)
    end

    # Sends the operation and returns its result.
    #
    # Every attempt gets a new request ID, timestamp and signature. Only temporary failures are retried.
    #
    # @api private
    def execute(operation)
      attempt = 0
      begin
        attempt += 1
        perform(operation, attempt)
      rescue TransportError, TemporaryError => e
        raise unless e.retryable? && operation.auto_retry? && attempt <= config.max_retries

        log(:warn) { "NAV #{operation.name} attempt #{attempt} failed, retrying: #{e.message}" }
        pause(retry_delay(attempt))
        retry
      end
    end

    private

    def perform(operation, attempt)
      request_id, xml = build_request(operation)
      config.throttle&.wait(operation.name) if operation.rate_limited?

      response = send_request(operation, xml, request_id, attempt)
      document = ResponseParser.parse(response, expected_root: operation.response_root, request_id:)
      operation.parse(document, request_id:, raw_xml: response.body)
    end

    def build_request(operation)
      request_id = config.request_id_generator.call
      xml = @builder.build(operation, request_id:, time: config.clock.call)
      SchemaValidator.validate!(xml) if config.validate_requests
      [request_id, xml]
    end

    def send_request(operation, xml, request_id, attempt)
      log_payload(operation, "request", xml)
      response, duration = timed { @transport.post(config.endpoint(operation.name), xml) }
      log(:info) do
        "NAV #{operation.name} request_id=#{request_id} attempt=#{attempt} status=#{response.status} " \
          "duration=#{duration}ms bytes=#{response.body.bytesize}"
      end
      log_payload(operation, "response", response.body)
      response
    end

    # Request and response XML can hold personal data and invoice contents, so they are logged only when the
    # configuration asks for it, and even then with credentials and invoice data hidden.
    def log_payload(operation, kind, xml)
      return unless config.log_payloads

      log(:debug) { "NAV #{operation.name} #{kind}: #{Redactor.redact(xml)}" }
    end

    # @return [Array(Object, Integer)] the block's result and its duration in milliseconds
    def timed
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      [result, ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round]
    end

    def retry_delay(attempt)
      config.retry_base_delay * (2**(attempt - 1)) * rand(0.8..1.2)
    end

    def pause(seconds)
      sleep(seconds) if seconds.positive?
    end

    def log(level, &)
      config.logger&.public_send(level, &)
    end
  end
end
