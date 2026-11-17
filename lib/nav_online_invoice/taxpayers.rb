# frozen_string_literal: true

module NavOnlineInvoice
  # Tax number lookups. Use through {Client#taxpayers}.
  class Taxpayers
    # @api private
    def initialize(client)
      @client = client
    end

    # Looks up a taxpayer by tax number.
    #
    # NAV checks only the first 8 digits; use {TaxpayerResult#matches?} to check a full tax number.
    #
    # @example
    #   result = client.taxpayers.query("12345678-2-42")
    #   result.matches?("12345678-2-42") # => true
    #   result.taxpayer.name             # => "EXAMPLE KFT."
    #   result.taxpayer.headquarters&.city
    # @param tax_number [String] 8 or 11 digits, hyphens allowed
    # @return [TaxpayerResult]
    # @raise [ArgumentError] if the tax number has the wrong format
    # @raise [Error] if NAV could not be asked or answered with an error
    def query(tax_number)
      @client.execute(Operations::QueryTaxpayer.new(tax_number))
    end
  end
end
