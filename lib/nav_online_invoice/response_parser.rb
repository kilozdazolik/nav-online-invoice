# frozen_string_literal: true

module NavOnlineInvoice
  # Turns NAV's answer into a parsed document, or raises the matching error.
  #
  # Elements are looked up by namespace URI, because NAV chooses its own prefixes (ns2, ns3, ...).
  #
  # @api private
  module ResponseParser
    class << self
      # Checks NAV's answer and returns it as a document.
      #
      # @param response [Transport::Response]
      # @param expected_root [String] the root element of a successful answer, e.g. "QueryTaxpayerResponse"
      # @param request_id [String] the ID of the request; NAV's exception responses do not repeat it
      # @return [Nokogiri::XML::Document]
      # @raise [ApiError, TransportError]
      def parse(response, expected_root:, request_id:)
        document = xml(response.body)
        root = document&.root
        # Anything that is not NAV's XML, e.g. an empty body or a proxy's HTML page.
        raise non_nav_error(response) unless root && NAMESPACES.value?(root.namespace&.href)

        error = error_in(root, response, expected_root, request_id)
        raise error if error

        document
      end

      private

      def xml(body)
        bytes = body.to_s.b
        return if bytes.strip.empty?

        # Raw bytes, so libxml2 decodes the body by its XML declaration, whatever the HTTP layer assumed.
        Nokogiri::XML(bytes) { |config| config.strict.nonet }
      rescue Nokogiri::XML::SyntaxError, EncodingError
        nil
      end

      def error_in(root, response, expected_root, request_id)
        case root_name(root)
        when ["api", expected_root] then result_error(root, response, request_id)
        when %w[api GeneralErrorResponse] then api_error(result(root), response, request_id, root)
        when %w[common GeneralExceptionResponse] then api_error(root, response, request_id)
        else
          TransportError.new("Unexpected #{root.name} response (HTTP #{response.status})",
                             http_status: response.status, retryable: false)
        end
      end

      def root_name(root)
        [NAMESPACES.key(root.namespace.href), root.name]
      end

      def result(root)
        root.at_xpath("common:result", NAMESPACES)
      end

      def result_error(root, response, request_id)
        return if text(result(root), "common:funcCode") == "OK"

        api_error(result(root), response, request_id, root)
      end

      def api_error(result, response, request_id, root = nil)
        code = text(result, "common:errorCode")
        ApiError.for(code).new(
          code: code,
          nav_message: text(result, "common:message"),
          request_id: request_id,
          http_status: response.status,
          technical_validation_messages: root ? technical_validation_messages(root) : []
        )
      end

      def technical_validation_messages(root)
        root.xpath("api:technicalValidationMessages", NAMESPACES).map do |node|
          ApiError::TechnicalValidationMessage.new(
            result_code: text(node, "common:validationResultCode"),
            error_code: text(node, "common:validationErrorCode"),
            message: text(node, "common:message")
          )
        end
      end

      def non_nav_error(response)
        status = response.status
        if status == 503
          return MaintenanceError.new(code: nil, nav_message: "NAV is unavailable (HTTP 503)", http_status: status)
        end

        # 404 without a body and a plain-text 500 mean a wrong URL or method: retrying will not help.
        TransportError.new("NAV sent no XML answer (HTTP #{status}): #{response.body.to_s.b[0, 200].scrub}",
                           http_status: status, retryable: [502, 504].include?(status))
      end

      def text(node, xpath)
        node&.at_xpath(xpath, NAMESPACES)&.text
      end
    end
  end
end
