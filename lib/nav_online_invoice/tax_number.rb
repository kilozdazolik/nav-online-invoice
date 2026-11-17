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
  end
end
