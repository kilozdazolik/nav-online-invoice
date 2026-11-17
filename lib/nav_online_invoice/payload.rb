# frozen_string_literal: true

module NavOnlineInvoice
  # Decodes the base64 (and optionally gzip) invoice data that NAV sends back.
  #
  # @api private
  module Payload
    module_function

    # @param base64 [String] NAV's xs:base64Binary value; line breaks are allowed
    # @param compressed [Boolean] NAV's compressedContentIndicator
    # @return [String] the decoded XML, UTF-8
    # @raise [DecodeError] if the data is not valid base64, gzip or UTF-8
    def decode(base64, compressed:)
      bytes = base64.to_s.delete(" \t\r\n").unpack1("m0")
      bytes = Zlib.gunzip(bytes) if compressed
      xml = bytes.force_encoding(Encoding::UTF_8)
      raise DecodeError, "invoice data is not valid UTF-8" unless xml.valid_encoding?

      xml
    rescue ArgumentError, Zlib::Error => e
      raise DecodeError, "invoice data could not be decoded: #{e.class}"
    end
  end
end
