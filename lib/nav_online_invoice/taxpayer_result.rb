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
  # @!attribute taxpayer
  #   @return [Taxpayer, nil]
  # @!attribute raw_xml
  #   @return [String] NAV's answer; contains personal data for sole traders
  class TaxpayerResult
    # Whether NAV confirmed that the tax number exists.
    #
    # NAV checks only the first 8 digits; use {#matches?} to check a full tax number.
    def valid?
      validity == true
    end

    # Whether the tax number exists and, if given with 11 digits, its VAT and county codes match NAV's data.
    #
    # @example
    #   result.matches?("12345678-2-42") # => false if NAV knows the company as 12345678-1-42
    # @param tax_number [String] 8 or 11 digits, hyphens allowed
    def matches?(tax_number)
      return false unless valid? && taxpayer

      digits = tax_number.to_s.delete(" -")
      expected = digits.length == 8 ? taxpayer.taxpayer_id : taxpayer.tax_number.delete("-")
      digits == expected
    end

    # Leaves out the raw XML.
    def inspect
      "#<data #{self.class.name} request_id=#{request_id.inspect}, validity=#{validity.inspect}, " \
        "info_date=#{info_date.inspect}, taxpayer=#{taxpayer.inspect}>"
    end
    alias to_s inspect

    # Used by +pp+, IRB and the Rails console.
    def pretty_print(printer)
      printer.text(inspect)
    end
  end
end
