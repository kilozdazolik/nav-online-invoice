# frozen_string_literal: true

module NavOnlineInvoice
  # Reads NAV's two address forms into an {Address}.
  #
  # @api private
  module AddressReader
    include XmlReader

    DETAILED_FIELDS = {
      country_code: "countryCode", region: "region", postal_code: "postalCode", city: "city",
      street_name: "streetName", public_place_category: "publicPlaceCategory", number: "number",
      building: "building", staircase: "staircase", floor: "floor", door: "door", lot_number: "lotNumber"
    }.freeze
    SIMPLE_FIELDS = {
      country_code: "countryCode", region: "region", postal_code: "postalCode", city: "city",
      additional_address_detail: "additionalAddressDetail"
    }.freeze
    private_constant :DETAILED_FIELDS, :SIMPLE_FIELDS

    private

    # @param node [Nokogiri::XML::Node] an element of base:DetailedAddressType
    def detailed_address(node, type: nil)
      Address.new(type:, **DETAILED_FIELDS.transform_values { |element| text(node, "base:#{element}") })
    end

    # @param node [Nokogiri::XML::Node, nil] an element of base:AddressType, which holds one of the two forms
    # @return [Address, nil]
    def address(node)
      if (simple = node&.at_xpath("base:simpleAddress", NAMESPACES))
        Address.new(**SIMPLE_FIELDS.transform_values { |element| text(simple, "base:#{element}") })
      elsif (detailed = node&.at_xpath("base:detailedAddress", NAMESPACES))
        detailed_address(detailed)
      end
    end
  end
end
