# frozen_string_literal: true

module NavOnlineInvoice
  # Turns NAV's answer into a parsed document, or raises the matching error.
  #
  # Elements are looked up by namespace URI, because NAV chooses its own prefixes (ns2, ns3, ...).
  #
  # @api private
  module ResponseParser
    module_function

    # @param response [Transport::Response]
    # @param expected_root [String] the root element of a successful answer, e.g. "QueryTaxpayerResponse"
    # @param request_id [String] the ID of the request; NAV's exception responses do not repeat it
    # @return [Nokogiri::XML::Document]
    # @raise [ApiError, TransportError]
    def parse(response, expected_root:, request_id:)
      document = xml(response.body)
      raise non_xml_error(response) unless document&.root

      error = error_in(document.root, response, expected_root, request_id)
      raise error if error

      document
    end

    def error_in(root, response, expected_root, request_id)
      result = root.at_xpath("common:result", NAMESPACES)
      case [root.namespace&.href, root.name]
      when [NAMESPACES["api"], expected_root]
        api_error(result, response, request_id, root) unless result && text(result, "common:funcCode") == "OK"
      when [NAMESPACES["api"], "GeneralErrorResponse"] then api_error(result, response, request_id, root)
      when [NAMESPACES["common"], "GeneralExceptionResponse"] then api_error(root, response, request_id)
      else
        TransportError.new("Unexpected #{root.name} response (HTTP #{response.status})",
                           http_status: response.status, retryable: false)
      end
    end

    def xml(body)
      return if body.to_s.strip.empty?

      Nokogiri::XML(body) { |config| config.strict.nonet }
    rescue Nokogiri::XML::SyntaxError
      nil
    end

    def api_error(result, response, request_id, root = nil)
      code = result && text(result, "common:errorCode")
      ApiError.for(code).new(
        code: code,
        nav_message: result && text(result, "common:message"),
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

    def non_xml_error(response)
      status = response.status
      if status == 503
        return MaintenanceError.new(code: nil, nav_message: "NAV is unavailable (HTTP 503)", http_status: status)
      end

      # 404 without a body and a plain-text 500 mean a wrong URL or method: retrying will not help.
      TransportError.new("NAV sent no XML (HTTP #{status}): #{response.body.to_s[0, 200]}",
                         http_status: status, retryable: [502, 504].include?(status))
    end

    def text(node, xpath)
      node.at_xpath(xpath, NAMESPACES)&.text
    end

    private_class_method :error_in, :xml, :api_error, :technical_validation_messages, :non_xml_error, :text
  end
end
