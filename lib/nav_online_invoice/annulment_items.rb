# frozen_string_literal: true

module NavOnlineInvoice
  # Builds and encodes the technical annulments of a submission before any request is sent (spec 2.4).
  #
  # @api private
  module AnnulmentItems
    CODES = %w[ERRATIC_DATA ERRATIC_INVOICE_NUMBER ERRATIC_INVOICE_ISSUE_DATE ERRATIC_ELECTRONIC_HASH_VALUE].freeze
    KEYS = %i[reference code reason timestamp].freeze

    module_function

    # @param items [Array<Hash>]
    # @param time [Time] the annulment timestamp of items that give none
    # @param validate [Boolean] check each annulment against the invoiceAnnulment schema
    # @return [Array<Operations::Manage::Item>]
    # @raise [ArgumentError, SchemaValidationError]
    def prepare(items, time:, validate:)
      ItemList.check(items).map.with_index(1) do |item, index|
        xml = xml(item, "items[#{index}]", time)
        SchemaValidator.validate!(xml, schema: :annulment) if validate
        Operations::Manage::Item.new(operation: "ANNUL", data: Payload.encode(xml, compressed: false))
      end
    end

    # @return [String] the InvoiceAnnulment XML
    def xml(item, name, time)
      values = values(item, name, time)
      Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.InvoiceAnnulment("xmlns" => NAMESPACES["annul"]) do
          values.each { |element, value| xml.public_send(element, value) }
        end
      end.to_xml
    end

    # @return [Hash{Symbol => String}] the elements in schema order
    def values(item, name, time)
      ItemList.known_keys!(name, item, KEYS)

      {
        annulmentReference: Params.text(:"#{name}[:reference]", item[:reference], max: 50),
        annulmentTimestamp: Params.timestamp(Params.time(:"#{name}[:timestamp]", item[:timestamp] || time)),
        annulmentCode: Params.enum(:"#{name}[:code]", item[:code], CODES),
        annulmentReason: Params.text(:"#{name}[:reason]", item[:reason], max: 1024)
      }
    end
  end
end
