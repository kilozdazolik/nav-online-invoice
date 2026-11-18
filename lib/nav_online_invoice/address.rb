# frozen_string_literal: true

module NavOnlineInvoice
  Address = Data.define(:type, :country_code, :region, :postal_code, :city, :street_name, :public_place_category,
                        :number, :building, :staircase, :floor, :door, :lot_number)

  # An address of a taxpayer, as NAV stores it.
  #
  # @!attribute type
  #   @return [Symbol] +:hq+ (registered office), +:site+ or +:branch+
  # @!attribute public_place_category
  #   @return [String] e.g. "UTCA" or "ÚT"
  class Address
    include Redacted

    def initialize(type:, country_code:, postal_code:, city:, street_name:, public_place_category:, region: nil,
                   number: nil, building: nil, staircase: nil, floor: nil, door: nil, lot_number: nil)
      super
    end

    # Leaves out the address itself: for a sole trader it is personal data.
    def inspect = "#<data #{self.class.name} type=#{type.inspect}, country_code=#{country_code.inspect}>"
  end
end
