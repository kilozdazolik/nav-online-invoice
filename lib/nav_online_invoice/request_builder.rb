# frozen_string_literal: true

module NavOnlineInvoice
  # Builds the XML of a request: the shared header, user and software parts plus the operation's body.
  #
  # @api private
  class RequestBuilder
    REQUEST_VERSION = "3.0"
    HEADER_VERSION = "1.0"

    # @param config [Configuration]
    def initialize(config)
      @config = config
    end

    # @param operation [#request_root, #index_hashes, #build_body] the operation to build
    # @param request_id [String]
    # @param time [Time] written into the header and used for the signature
    # @return [String] the request XML
    def build(operation, request_id:, time:)
      Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.public_send(operation.request_root, "xmlns" => NAMESPACES["api"],
                                                "xmlns:common" => NAMESPACES["common"]) do
          header(xml, request_id, time)
          user(xml, request_id, time, operation.index_hashes)
          software(xml)
          operation.build_body(xml)
        end
      end.to_xml
    end

    private

    def header(xml, request_id, time)
      xml["common"].header do
        xml["common"].requestId request_id
        xml["common"].timestamp Params.timestamp(time)
        xml["common"].requestVersion REQUEST_VERSION
        xml["common"].headerVersion HEADER_VERSION
      end
    end

    def user(xml, request_id, time, index_hashes)
      signature = Crypto.request_signature(request_id, time, @config.signature_key, index_hashes:)
      xml["common"].user do
        xml["common"].login @config.login
        xml["common"].passwordHash(@config.password_hash, "cryptoType" => "SHA-512")
        xml["common"].taxNumber @config.tax_number
        xml["common"].requestSignature(signature, "cryptoType" => "SHA3-512")
      end
    end

    def software(xml)
      software = @config.software
      fields = {
        softwareId: software.id,
        softwareName: software.name,
        softwareOperation: software.operation.to_s.upcase,
        softwareMainVersion: software.main_version,
        softwareDevName: software.dev_name,
        softwareDevContact: software.dev_contact,
        softwareDevCountryCode: software.dev_country_code,
        softwareDevTaxNumber: software.dev_tax_number
      }
      xml.software do
        fields.compact.each { |name, value| xml.public_send(name, value) }
      end
    end
  end
end
