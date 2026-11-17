# frozen_string_literal: true

module NavOnlineInvoice
  # A business rule finding of NAV on a submitted invoice.
  #
  # @!attribute result_code
  #   @return [Symbol] +:error+ (the invoice is rejected), +:warn+ or +:info+
  # @!attribute error_code
  #   @return [String, nil] NAV's code, e.g. "INVOICE_LINE_MISSING"
  # @!attribute tag
  #   @return [String, nil] the element NAV points to
  # @!attribute line
  #   @return [Integer, nil] the invoice line NAV points to
  BusinessValidationMessage = Data.define(:result_code, :error_code, :message, :tag, :value, :line,
                                          :original_invoice_number)
end
