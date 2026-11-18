# frozen_string_literal: true

module NavOnlineInvoice
  Taxpayer = Data.define(:name, :short_name, :taxpayer_id, :vat_code, :county_code, :incorporation,
                         :vat_group_membership, :addresses)

  # A company or sole trader registered at NAV.
  #
  # @!attribute taxpayer_id
  #   @return [String] the first 8 digits of the tax number
  # @!attribute short_name
  #   @return [String, nil] NAV does not fill this at present
  # @!attribute incorporation
  #   @return [Symbol] +:organization+, +:self_employed+ or +:taxable_person+
  # @!attribute addresses
  #   @return [Array<Address>]
  class Taxpayer
    include Redacted

    def initialize(name:, taxpayer_id:, incorporation:, short_name: nil, vat_code: nil, county_code: nil,
                   vat_group_membership: nil, addresses: [])
      super(name:, short_name:, taxpayer_id:, vat_code:, county_code:, incorporation:, vat_group_membership:,
            addresses: addresses.dup.freeze)
    end

    # The tax number as written on invoices, e.g. "12345678-2-42".
    #
    # @return [String] only the 8-digit part if NAV did not send the VAT and county codes
    def tax_number
      return taxpayer_id unless vat_code && county_code

      "#{taxpayer_id}-#{vat_code}-#{county_code}"
    end

    # Leaves out the name and the addresses: for a sole trader they are personal data.
    def inspect
      "#<data #{self.class.name} taxpayer_id=#{taxpayer_id.inspect}, incorporation=#{incorporation.inspect}, " \
        "addresses=#{addresses.size}>"
    end

    # The registered office.
    #
    # @return [Address, nil]
    def headquarters
      addresses.find { |address| address.type == :hq }
    end
  end
end
