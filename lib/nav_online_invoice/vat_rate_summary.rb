# frozen_string_literal: true

module NavOnlineInvoice
  VatRateSummary = Data.define(:vat_rate, :net_amount, :net_amount_huf, :vat_amount, :vat_amount_huf,
                               :gross_amount, :gross_amount_huf)

  # The totals of one VAT rate on an invoice. Amounts are in the invoice's currency unless they end in `_huf`.
  #
  # @!attribute vat_rate
  #   @return [VatRate]
  # @!attribute net_amount
  #   @return [BigDecimal, nil] nil on simplified invoices
  # @!attribute net_amount_huf
  #   @return [BigDecimal, nil]
  # @!attribute vat_amount
  #   @return [BigDecimal, nil] nil on simplified invoices
  # @!attribute vat_amount_huf
  #   @return [BigDecimal, nil]
  # @!attribute gross_amount
  #   @return [BigDecimal, nil] always given on simplified invoices, optional on others
  # @!attribute gross_amount_huf
  #   @return [BigDecimal, nil]
  class VatRateSummary
    include Redacted
    include DeepHash

    def initialize(vat_rate:, net_amount: nil, net_amount_huf: nil, vat_amount: nil, vat_amount_huf: nil,
                   gross_amount: nil, gross_amount_huf: nil)
      super
    end

    # Leaves out the amounts, which are invoice contents.
    def inspect = "#<data #{self.class.name} vat_rate=#{vat_rate.inspect}>"
  end
end
