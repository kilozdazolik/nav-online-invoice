# frozen_string_literal: true

module NavOnlineInvoice
  # Hides credentials and invoice data in XML before it is logged.
  #
  # @api private
  module Redactor
    FILTERED = "[FILTERED]"
    ELEMENTS = %w[login passwordHash requestSignature exchangeToken encodedExchangeToken].freeze

    PAYLOADS = %w[invoiceData invoiceAnnulment originalRequest].freeze

    PATTERN = %r{(<(?:\w+:)?(?:#{ELEMENTS.join("|")})(?:\s[^>]*)?>)[^<]*(</)}
    PAYLOAD_PATTERN = %r{(<(?:\w+:)?(?:#{PAYLOADS.join("|")})(?:\s[^>]*)?>)([^<]*)(</)}
    private_constant :PATTERN, :PAYLOAD_PATTERN

    module_function

    # Replaces the credentials, the exchange tokens and the base64 invoice and annulment data with [FILTERED].
    #
    # @param xml [String]
    # @return [String]
    def redact(xml)
      xml.to_s.scrub.gsub(PATTERN, "\\1#{FILTERED}\\2").gsub(PAYLOAD_PATTERN) do
        open_tag, content, close_tag = Regexp.last_match.captures
        "#{open_tag}[FILTERED #{content.bytesize} bytes]#{close_tag}"
      end
    end
  end
end
