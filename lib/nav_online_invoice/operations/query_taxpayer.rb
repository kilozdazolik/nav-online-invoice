# frozen_string_literal: true

module NavOnlineInvoice
  # One class per NAV operation: what to send and how to read the answer.
  #
  # @api private
  module Operations
    # Looks up a taxpayer by tax number.
    class QueryTaxpayer
      include XmlReader

      ADDRESS_FIELDS = {
        country_code: "countryCode", region: "region", postal_code: "postalCode", city: "city",
        street_name: "streetName", public_place_category: "publicPlaceCategory", number: "number",
        building: "building", staircase: "staircase", floor: "floor", door: "door", lot_number: "lotNumber"
      }.freeze
      private_constant :ADDRESS_FIELDS

      # @param tax_number [String] 8 or 11 digits
      # @raise [ArgumentError] if the tax number has the wrong format
      def initialize(tax_number)
        @tax_number = TaxNumber.normalize(tax_number)
      end

      def name = "queryTaxpayer"
      def request_root = "QueryTaxpayerRequest"
      def response_root = "QueryTaxpayerResponse"
      def rate_limited? = true
      def auto_retry? = true

      def build_body(xml)
        xml.taxNumber @tax_number
      end

      # @param document [Nokogiri::XML::Document] a successful QueryTaxpayerResponse
      # @return [TaxpayerResult]
      def parse(document, request_id:, raw_xml:)
        root = document.root
        TaxpayerResult.new(
          request_id: request_id,
          info_date: time(root, "api:infoDate"),
          validity: boolean(root, "api:taxpayerValidity"),
          taxpayer: root.at_xpath("api:taxpayerData", NAMESPACES)&.then { |node| taxpayer(node) },
          raw_xml: raw_xml
        )
      end

      private

      def taxpayer(node)
        detail = node.at_xpath("api:taxNumberDetail", NAMESPACES)
        Taxpayer.new(
          name: text(node, "api:taxpayerName"),
          short_name: text(node, "api:taxpayerShortName"),
          taxpayer_id: text(detail, "base:taxpayerId"),
          vat_code: text(detail, "base:vatCode"),
          county_code: text(detail, "base:countyCode"),
          incorporation: symbol(node, "api:incorporation"),
          vat_group_membership: text(node, "api:vatGroupMembership"),
          addresses: node.xpath("api:taxpayerAddressList/api:taxpayerAddressItem", NAMESPACES).map { address(_1) }
        )
      end

      def address(item)
        place = item.at_xpath("api:taxpayerAddress", NAMESPACES)
        Address.new(type: symbol(item, "api:taxpayerAddressType"),
                    **ADDRESS_FIELDS.transform_values { |element| text(place, "base:#{element}") })
      end
    end
  end
end
