# frozen_string_literal: true

module NavOnlineInvoice
  Address = Data.define(:type, :country_code, :region, :postal_code, :city, :street_name, :public_place_category,
                        :number, :building, :staircase, :floor, :door, :lot_number, :additional_address_detail)

  # An address as NAV stores it: a taxpayer's registered address, or the address of a party on an invoice.
  #
  # NAV has two forms. A detailed address has the street parts; a simple one has the city and postal code, and the
  # rest as one line in {#additional_address_detail}. Taxpayer addresses are always detailed.
  #
  # @!attribute type
  #   @return [Symbol, nil] for taxpayer addresses: `:hq` (registered office), `:site` or `:branch`; nil on invoices
  # @!attribute country_code
  #   @return [String] e.g. "HU"
  # @!attribute region
  #   @return [String, nil]
  # @!attribute postal_code
  #   @return [String]
  # @!attribute city
  #   @return [String]
  # @!attribute street_name
  #   @return [String, nil] nil in a simple address
  # @!attribute public_place_category
  #   @return [String, nil] e.g. "UTCA" or "ÚT"; nil in a simple address
  # @!attribute number
  #   @return [String, nil]
  # @!attribute building
  #   @return [String, nil]
  # @!attribute staircase
  #   @return [String, nil]
  # @!attribute floor
  #   @return [String, nil]
  # @!attribute door
  #   @return [String, nil]
  # @!attribute lot_number
  #   @return [String, nil]
  # @!attribute additional_address_detail
  #   @return [String, nil] the street, number and the rest, in a simple address only
  class Address
    include Redacted

    def initialize(country_code:, postal_code:, city:, type: nil, street_name: nil, public_place_category: nil,
                   region: nil, number: nil, building: nil, staircase: nil, floor: nil, door: nil, lot_number: nil,
                   additional_address_detail: nil)
      super
    end

    # Whether this is a simple address, with the street parts in {#additional_address_detail}.
    def simple? = !additional_address_detail.nil?

    # Leaves out the address itself: for a sole trader it is personal data.
    def inspect = "#<data #{self.class.name} type=#{type.inspect}, country_code=#{country_code.inspect}>"
  end
end
