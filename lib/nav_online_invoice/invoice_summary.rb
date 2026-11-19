# frozen_string_literal: true

module NavOnlineInvoice
  InvoiceSummary = Data.define(:simplified, :net_amount, :net_amount_huf, :vat_amount, :vat_amount_huf,
                               :gross_amount, :gross_amount_huf, :gross_calculated, :by_vat_rate)

  # The totals of an invoice. Amounts are in the invoice's currency unless they end in `_huf`.
  #
  # On a modification or storno invoice every amount is the signed change, not the new total: see
  # {Invoice#modification?}.
  #
  # @!attribute simplified
  #   @return [Boolean] whether it is a simplified invoice, which has only gross amounts per VAT content
  # @!attribute net_amount
  #   @return [BigDecimal, nil] nil on simplified invoices
  # @!attribute net_amount_huf
  #   @return [BigDecimal, nil]
  # @!attribute vat_amount
  #   @return [BigDecimal, nil] nil on simplified invoices
  # @!attribute vat_amount_huf
  #   @return [BigDecimal, nil]
  # @!attribute gross_amount
  #   @return [BigDecimal] as the invoice states it, or calculated when it does not: see {#gross_calculated?}
  # @!attribute gross_amount_huf
  #   @return [BigDecimal]
  # @!attribute gross_calculated
  #   @return [Boolean] see {#gross_calculated?}
  # @!attribute by_vat_rate
  #   @return [Array<VatRateSummary>]
  class InvoiceSummary
    include Redacted
    include DeepHash

    def initialize(simplified:, gross_amount:, gross_amount_huf:, gross_calculated:, by_vat_rate:, net_amount: nil,
                   net_amount_huf: nil, vat_amount: nil, vat_amount_huf: nil)
      super(simplified:, net_amount:, net_amount_huf:, vat_amount:, vat_amount_huf:, gross_amount:,
            gross_amount_huf:, gross_calculated:, by_vat_rate: by_vat_rate.dup.freeze)
    end

    def simplified? = simplified

    # Whether the invoice gave no gross total, which NAV allows, so the gem added it up: net plus VAT, or on a
    # simplified invoice the gross amounts of the VAT rates. NAV checks the same sums when the total is given.
    def gross_calculated? = gross_calculated

    # Leaves out the amounts, which are invoice contents.
    def inspect
      "#<data #{self.class.name} simplified=#{simplified.inspect}, vat_rates=#{by_vat_rate.size}>"
    end
  end
end
