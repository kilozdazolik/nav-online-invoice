# frozen_string_literal: true

module NavOnlineInvoice
  TaxpayerResult = Data.define(:request_id, :info_date, :validity, :taxpayer, :raw_xml)

  # Result of a tax number lookup.
  #
  # An unknown tax number is not an error: {#valid?} is false and {#taxpayer} is nil.
  #
  # @!attribute validity
  #   @return [Boolean, nil] NAV's answer; nil if NAV did not say
  # @!attribute info_date
  #   @return [Time, nil] when NAV's data last changed
  # @!attribute raw_xml
  #   @return [String] NAV's answer; contains personal data for sole traders
  class TaxpayerResult
    # Whether NAV confirmed that the tax number exists.
    def valid?
      validity == true
    end

    # Leaves out the raw XML.
    def inspect
      "#<data #{self.class.name} request_id=#{request_id.inspect}, validity=#{validity.inspect}, " \
        "info_date=#{info_date.inspect}, taxpayer=#{taxpayer.inspect}>"
    end
    alias to_s inspect
  end

  Taxpayer = Data.define(:name, :short_name, :taxpayer_id, :vat_code, :county_code, :incorporation,
                         :vat_group_membership, :addresses)

  # A company or sole trader registered at NAV.
  #
  # @!attribute short_name
  #   @return [String, nil] NAV does not fill this at present
  # @!attribute incorporation
  #   @return [Symbol] +:organization+, +:self_employed+ or +:taxable_person+
  # @!attribute addresses
  #   @return [Array<Address>]
  class Taxpayer
    def initialize(name:, taxpayer_id:, incorporation:, short_name: nil, vat_code: nil, county_code: nil,
                   vat_group_membership: nil, addresses: [])
      super(name:, short_name:, taxpayer_id:, vat_code:, county_code:, incorporation:, vat_group_membership:,
            addresses: addresses.freeze)
    end

    # The tax number as written on invoices, e.g. "12345678-2-42".
    #
    # @return [String] only the 8-digit part if NAV did not send the VAT and county codes
    def tax_number
      return taxpayer_id unless vat_code && county_code

      "#{taxpayer_id}-#{vat_code}-#{county_code}"
    end

    # @return [Address, nil] the registered office
    def headquarters
      addresses.find { |address| address.type == :hq }
    end
  end

  Address = Data.define(:type, :country_code, :region, :postal_code, :city, :street_name, :public_place_category,
                        :number, :building, :staircase, :floor, :door, :lot_number)

  # An address of a taxpayer, as NAV stores it.
  #
  # @!attribute type
  #   @return [Symbol] +:hq+ (registered office), +:site+ or +:branch+
  # @!attribute public_place_category
  #   @return [String] e.g. "UTCA" or "ÚT"
  class Address
    def initialize(type:, country_code:, postal_code:, city:, street_name:, public_place_category:, region: nil,
                   number: nil, building: nil, staircase: nil, floor: nil, door: nil, lot_number: nil)
      super
    end
  end
end
