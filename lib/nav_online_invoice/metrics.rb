# frozen_string_literal: true

module NavOnlineInvoice
  # NAV's service metrics: average response and processing times of the last hour (spec chapter 8).
  #
  # Needs no technical user, so it works without a configuration. NAV refreshes the metrics once a minute.
  #
  # @example
  #   metrics = NavOnlineInvoice::Metrics.new(environment: :production)
  #   metrics.get("responseTimeAverageMsManageInvoice")&.values&.last&.value # => 412.5 (ms)
  class Metrics
    include XmlReader

    ENDPOINTS = {
      test: "https://api-test.onlineszamla.nav.gov.hu/metricService/v3/queryServiceMetrics/",
      production: "https://api.onlineszamla.nav.gov.hu/metricService/v3/queryServiceMetrics/"
    }.freeze

    # @param environment [Symbol] +:test+ or +:production+
    # @param open_timeout [Numeric] seconds
    # @param read_timeout [Numeric] seconds
    # @param max_retries [Integer] how often a temporary network failure is retried
    # @param retry_base_delay [Numeric] seconds before the first retry; doubles on each retry
    # @param logger [Logger, nil] gets one line per request
    # @raise [ArgumentError] if the environment is unknown
    def initialize(environment: :test, open_timeout: 5, read_timeout: 10, max_retries: 2, retry_base_delay: 1.0,
                   logger: nil)
      raise ArgumentError, "environment must be :test or :production" unless ENDPOINTS.key?(environment)
      unless max_retries.is_a?(Integer) && max_retries >= 0
        raise ArgumentError, "max_retries must be an Integer of 0 or more"
      end
      unless retry_base_delay.is_a?(Numeric) && !retry_base_delay.negative?
        raise ArgumentError, "retry_base_delay must be a number of 0 or more"
      end

      @base = ENDPOINTS.fetch(environment)
      @transport = Transport.new(open_timeout:, read_timeout:, write_timeout: read_timeout)
      @max_retries = max_retries
      @retry_base_delay = retry_base_delay
      @logger = logger
    end

    # All metrics with their values.
    #
    # @return [ServiceMetrics]
    # @raise [ApiError, TransportError]
    def all
      root = fetch("metric", "QueryServiceMetricsResponse")
      ServiceMetrics.new(updated_at: time(root, "metrics:metricsLastUpdateTime"),
                         metrics: root.xpath("metrics:metric", NAMESPACES).map { |node| metric(node) })
    end

    # One metric with its values.
    #
    # @param name [String] e.g. "responseTimeAverageMsQueryTaxpayer"
    # @return [Metric, nil] nil if NAV has no such metric
    # @raise [ApiError, TransportError]
    def get(name)
      raise ArgumentError, "name must be a metric name, got #{name.inspect}" unless name.to_s.match?(/\A\w+\z/)

      root = fetch("metric/#{name}", "QueryServiceMetricsResponse", allow_missing: true)
      node = root&.at_xpath("metrics:metric", NAMESPACES)
      node && metric(node)
    end

    # The names and descriptions of the metrics, without values.
    #
    # @return [Array<MetricDefinition>]
    # @raise [TransportError]
    def definitions
      fetch("list", "QueryServiceMetricsListResponse").xpath("metrics:metricDefinition", NAMESPACES)
                                                      .map { |node| definition(node) }
    end

    private

    def metric(node)
      definition = definition(node.at_xpath("metrics:metricDefinition", NAMESPACES))
      Metric.new(**definition.to_h, values: node.xpath("metrics:metricValues", NAMESPACES).map do |value|
        MetricValue.new(timestamp: time(value, "metrics:timestamp"), value: decimal(value, "metrics:value"))
      end)
    end

    def definition(node)
      descriptions = node.xpath("metrics:metricDescription", NAMESPACES).to_h do |description|
        [symbol(description, "metrics:language"), text(description, "metrics:localizedDescription")]
      end
      MetricDefinition.new(name: text(node, "metrics:metricName"), type: symbol(node, "metrics:metricType"),
                           descriptions:)
    end

    # GET is safe to repeat, so temporary network failures are retried.
    def fetch(path, root_name, allow_missing: false)
      attempt = 0
      begin
        attempt += 1
        answer(URI("#{@base}#{path}"), root_name, allow_missing)
      rescue TransportError => e
        raise unless e.retryable? && attempt <= @max_retries

        Retry.wait(attempt, base_delay: @retry_base_delay, logger: @logger,
                            message: "queryServiceMetrics: #{e.message}")
        retry
      end
    end

    # @param allow_missing [Boolean] return nil for HTTP 404, which NAV sends for an unknown metric
    def answer(uri, root_name, allow_missing)
      response = @transport.get(uri)
      @logger&.info { "NAV queryServiceMetrics #{uri.path} status=#{response.status}" }
      return if allow_missing && response.status == 404

      check_result(metrics_root(response, root_name), response)
    end

    def metrics_root(response, root_name)
      root = document(response)&.root
      return root if root&.name == root_name && root.namespace&.href == NAMESPACES["metrics"]

      raise TransportError.new("NAV sent no metrics (HTTP #{response.status})", http_status: response.status,
                                                                                retryable: response.status >= 500)
    end

    def document(response)
      Nokogiri::XML(response.body.to_s.b) { |config| config.strict.nonet }
    rescue Nokogiri::XML::SyntaxError
      nil
    end

    def check_result(root, response)
      code = text(root, "metrics:result/common:funcCode")
      return root unless code == "ERROR"

      error_code = text(root, "metrics:result/common:errorCode")
      raise ApiError.for(error_code).new(code: error_code, nav_message: text(root, "metrics:result/common:message"),
                                         http_status: response.status)
    end
  end
end
