# frozen_string_literal: true

module NavOnlineInvoice
  # Hides credentials in request XML before it is logged.
  module Redactor
    FILTERED = "[FILTERED]"
    ELEMENTS = %w[login passwordHash requestSignature].freeze

    PATTERN = %r{(<(?:\w+:)?(?:#{ELEMENTS.join("|")})(?:\s[^>]*)?>)[^<]*(</)}
    private_constant :PATTERN

    module_function

    # @param xml [String]
    # @return [String] the XML with the login, password hash and signature replaced by [FILTERED]
    def redact(xml)
      xml.gsub(PATTERN, "\\1#{FILTERED}\\2")
    end
  end
end
