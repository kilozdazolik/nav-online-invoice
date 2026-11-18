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

    # @return [String, nil] the predecessor company this client acts for, see {#with_predecessor}
    attr_reader :predecessor_tax_number

    # @param config [Configuration] defaults to the one set with {NavOnlineInvoice.configure}
    # @param predecessor_tax_number [String, nil] see {#with_predecessor}
    # @raise [ArgumentError] if the predecessor's tax number is malformed
    def initialize(config = NavOnlineInvoice.configuration, predecessor_tax_number: nil)
      @config = config
      if predecessor_tax_number
        @predecessor_tax_number = Params.tax_number(:predecessor_tax_number, predecessor_tax_number)
      end
      @builder = RequestBuilder.new(config, predecessor_tax_number: @predecessor_tax_number)
      @transport = Transport.new(open_timeout: config.open_timeout, read_timeout: config.read_timeout,
                                 write_timeout: config.write_timeout)
      @taxpayers = Taxpayers.new(self)
      @invoices = Invoices.new(self)
      @transactions = Transactions.new(self)
    end

    # NAV's service metrics, in this client's environment.
    #
    # @return [Metrics]
    def metrics
      @metrics ||= Metrics.new(environment: config.environment, open_timeout: config.open_timeout,
                               read_timeout: config.read_timeout, max_retries: config.max_retries,
                               retry_base_delay: config.retry_base_delay, logger: config.logger)
    end

    # Returns a client that works with the data of a predecessor company (spec 1.10).
    #
    # Its queries search the predecessor's invoices and submissions, and its annulments annul the predecessor's
    # invoices. Tax number lookups and submissions are not affected. The original client is unchanged.
    #
    # @example
    #   client.with_predecessor("11111111-2-41").invoices.digest(direction: :outbound, issue_date: from..to)
    # @param tax_number [String] the predecessor's tax number, 8 or 11 digits
    # @return [Client]
    # @raise [ArgumentError] if the tax number is malformed
    def with_predecessor(tax_number)
      self.class.new(config, predecessor_tax_number: tax_number)
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
      request_id, time, xml = build_request(operation)
      config.throttle&.wait(operation.name) if operation.rate_limited?
      operation.check_before_send!

      document, body = answer(operation, xml, request_id, attempt)
      operation.parse(document, request_id:, raw_xml: body)
    rescue TransportError, MaintenanceError => e
      raise unknown_outcome(operation, e, request_id, time)
    end

    def answer(operation, xml, request_id, attempt)
      response = send_request(operation, xml, request_id, attempt)
      [ResponseParser.parse(response, expected_root: operation.response_root, request_id:), response.body]
    end

    # @return [Exception] the error to raise: UnknownOutcomeError if a submission may have arrived
    def unknown_outcome(operation, error, request_id, time)
      return error unless operation.submission? && outcome_unknown?(error)

      UnknownOutcomeError.new(operation: operation.name, request_id:, sent_at: operation.sent_at || time,
                              item_count: operation.index_hashes.size)
    end

    # A NAV error answer means the submission was rejected. Without one, it may have arrived: a 503 without a
    # NAV body can come from a network device while NAV is still processing.
    def outcome_unknown?(error)
      error.is_a?(TransportError) ? error.request_sent? : error.code.nil?
    end

    def build_request(operation)
      request_id = config.request_id_generator.call
      time = config.clock.call
      xml = @builder.build(operation, request_id:, time:)
      SchemaValidator.validate!(xml) if config.validate_requests
      check_size(operation, xml)
      [request_id, time, xml]
    end

    def check_size(operation, xml)
      limit = operation.max_body_bytes
      return unless limit && xml.bytesize > limit

      raise SubmissionTooLargeError, "the #{operation.name} request is #{xml.bytesize} bytes; NAV accepts at most " \
                                     "#{limit} (spec 1.6.5)"
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
      started = Monotonic.now
      result = yield
      [result, ((Monotonic.now - started) * 1000).round]
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
