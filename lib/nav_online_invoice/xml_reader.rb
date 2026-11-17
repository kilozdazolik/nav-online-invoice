# frozen_string_literal: true

module NavOnlineInvoice
  # Typed readers for NAV's response XML.
  #
  # Every reader takes a node and an XPath with the api/common/base prefixes, and returns nil when the node or
  # the element is missing or its value cannot be read.
  #
  # @api private
  module XmlReader
    BOOLEANS = { "true" => true, "1" => true, "false" => false, "0" => false }.freeze
    private_constant :BOOLEANS

    private

    def text(node, xpath)
      node&.at_xpath(xpath, NAMESPACES)&.text
    end

    def boolean(node, xpath)
      BOOLEANS[text(node, xpath)&.strip]
    end

    def integer(node, xpath)
      value = text(node, xpath)
      value && Integer(value.strip, 10, exception: false)
    end

    def decimal(node, xpath)
      value = text(node, xpath)&.strip
      value&.match?(/\A-?\d+(\.\d+)?\z/) ? BigDecimal(value) : nil
    end

    def date(node, xpath)
      value = text(node, xpath)
      value && Date.iso8601(value.strip)
    rescue Date::Error
      nil
    end

    def time(node, xpath)
      value = text(node, xpath)
      value && Time.iso8601(value.strip)
    rescue ArgumentError
      nil
    end

    def symbol(node, xpath)
      value = text(node, xpath)
      return unless value

      value.strip.downcase.to_sym
    end

    def technical_validation_messages(node)
      node.xpath("api:technicalValidationMessages", NAMESPACES).map do |message|
        ApiError::TechnicalValidationMessage.new(
          result_code: symbol(message, "common:validationResultCode"),
          error_code: text(message, "common:validationErrorCode"),
          message: text(message, "common:message")
        )
      end
    end
  end
end
