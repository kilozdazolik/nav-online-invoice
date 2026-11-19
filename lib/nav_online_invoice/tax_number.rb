# frozen_string_literal: true

module NavOnlineInvoice
  # Hungarian tax number handling.
  module TaxNumber
    module_function

    # Returns the 8-digit taxpayer ID that NAV expects.
    #
    # Accepts the 8-digit form and the full 11-digit form, with or without hyphens and spaces.
    #
    # @example
    #   TaxNumber.normalize("12345678-2-42") # => "12345678"
    # @param value [String, Integer]
    # @return [String]
    # @raise [ArgumentError] if the value is not an 8- or 11-digit tax number
    def normalize(value)
      digits = value.to_s.delete(" -")
      raise ArgumentError, "Invalid tax number: #{value.inspect}" unless digits.match?(/\A(\d{8}|\d{11})\z/)

      digits[0, 8]
    end

    # Writes a tax number the way invoices show it.
    #
    # @example
    #   TaxNumber.format("12345678", "2", "42") # => "12345678-2-42"
    # @param taxpayer_id [String, nil] the first 8 digits
    # @param vat_code [String, nil]
    # @param county_code [String, nil]
    # @return [String, nil] only the 8 digits if a code is missing; nil without a taxpayer ID
    def format(taxpayer_id, vat_code = nil, county_code = nil)
      return unless taxpayer_id
      return taxpayer_id unless vat_code && county_code

      "#{taxpayer_id}-#{vat_code}-#{county_code}"
    end
  end
end
