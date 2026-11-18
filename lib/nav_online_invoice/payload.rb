# frozen_string_literal: true

module NavOnlineInvoice
  # Encodes and decodes the base64 (and optionally gzip) data inside NAV requests and responses.
  #
  # @api private
  module Payload
    # NAV accepts at most 15 MB per invoice (spec 1.6.5); anything much larger is not an invoice.
    MAX_DECODED_BYTES = 20_000_000

    module_function

    # @param xml [String]
    # @param compressed [Boolean] gzip the data first, at the fastest level as NAV asks (spec 1.6.5)
    # @return [String] strict base64 without line breaks, as it goes into the request and the index hash
    def encode(xml, compressed:)
      bytes = compressed ? Zlib.gzip(xml, level: Zlib::BEST_SPEED) : xml
      [bytes].pack("m0").freeze
    end

    # @param base64 [String] NAV's xs:base64Binary value; line breaks are allowed
    # @param compressed [Boolean] NAV's compressedContentIndicator
    # @return [String] the decoded XML, UTF-8
    # @raise [DecodeError] if the data is not valid base64, gzip or UTF-8
    def decode(base64, compressed:)
      bytes = base64.to_s.delete(" \t\r\n").unpack1("m0")
      bytes = gunzip(bytes) if compressed
      xml = bytes.force_encoding(Encoding::UTF_8)
      raise DecodeError, "invoice data is not valid UTF-8" unless xml.valid_encoding?

      xml
    rescue ArgumentError, Zlib::Error => e
      raise DecodeError, "invoice data could not be decoded: #{e.class}"
    end

    # Unpacks in chunks and stops at the limit, so a small, highly compressed answer cannot fill the memory.
    def gunzip(bytes)
      reader = Zlib::GzipReader.new(StringIO.new(bytes))
      xml = reader.read(MAX_DECODED_BYTES + 1) || +""
      return xml if xml.bytesize <= MAX_DECODED_BYTES

      raise DecodeError, "invoice data is larger than #{MAX_DECODED_BYTES} bytes once unpacked"
    ensure
      reader&.close
    end
  end
end
