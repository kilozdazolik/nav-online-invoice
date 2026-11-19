# frozen_string_literal: true

module NavOnlineInvoice
  VatRate = Data.define(:kind, :rate, :code, :reason)

  # The VAT rate of a summary line, in one of NAV's eight forms.
  #
  # @!attribute kind
  #   @return [Symbol] `:percentage`, `:content` (simplified invoices), `:exemption`, `:out_of_scope`,
  #     `:domestic_reverse_charge`, `:margin_scheme`, `:amount_mismatch` or `:no_vat_charge`
  # @!attribute rate
  #   @return [BigDecimal, nil] e.g. 0.27, for `:percentage`, `:content` and `:amount_mismatch`
  # @!attribute code
  #   @return [String, nil] the exemption or out-of-scope case (e.g. "AAM"), the margin scheme (e.g. "SECOND_HAND")
  #     or the amount mismatch case
  # @!attribute reason
  #   @return [String, nil] the exemption or out-of-scope reason, as written on the invoice
  class VatRate
    include Redacted
    include DeepHash

    def initialize(kind:, rate: nil, code: nil, reason: nil)
      super
    end
  end
end
