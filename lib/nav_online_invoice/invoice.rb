# frozen_string_literal: true

module NavOnlineInvoice
  Invoice = Data.define(
    :invoice_number, :issue_date, :completeness_indicator, :batch_index, :reference,
    :supplier, :customer, :fiscal_representative,
    :category, :delivery_date, :delivery_period_start, :delivery_period_end, :accounting_delivery_date,
    :currency, :exchange_rate, :payment_method, :payment_date, :appearance,
    :periodical_settlement, :small_business, :cash_accounting, :self_billing, :utility_settlement,
    :summary
  )

  # One invoice read from NAV's InvoiceData, as returned by {InvoiceDataResult#invoice}. Lines are not included;
  # read them from {InvoiceDataResult#document}.
  #
  # A modification or storno invoice states only what changed: its amounts are signed differences against the
  # invoice as it stood, and parts of the header it did not change may be missing. See {#modification?}.
  #
  # `to_h` returns every field as nested hashes, e.g. to store or send as JSON. It holds names, addresses and bank
  # account numbers, so do not log it.
  #
  # @!attribute invoice_number
  #   @return [String]
  # @!attribute issue_date
  #   @return [Date]
  # @!attribute completeness_indicator
  #   @return [Boolean] whether the data sent to NAV is the electronic invoice itself
  # @!attribute batch_index
  #   @return [Integer, nil] the position within a batch modification
  # @!attribute reference
  #   @return [InvoiceReference, nil] the invoice this one modifies
  # @!attribute supplier
  #   @return [InvoiceParty]
  # @!attribute customer
  #   @return [InvoiceParty, nil] nil if not given, e.g. on a modification that does not change it
  # @!attribute fiscal_representative
  #   @return [InvoiceParty, nil]
  # @!attribute category
  #   @return [Symbol] `:normal`, `:simplified` or `:aggregate`; on a modification, the original invoice's
  # @!attribute delivery_date
  #   @return [Date] on an aggregate invoice, the latest delivery
  # @!attribute delivery_period_start
  #   @return [Date, nil]
  # @!attribute delivery_period_end
  #   @return [Date, nil]
  # @!attribute accounting_delivery_date
  #   @return [Date, nil]
  # @!attribute currency
  #   @return [String] ISO 4217, e.g. "HUF" or "EUR"
  # @!attribute exchange_rate
  #   @return [BigDecimal] the HUF value of one unit of the currency; 1 for HUF. On an aggregate invoice the lines
  #     may have their own rates, and this one is derived from the totals.
  # @!attribute payment_method
  #   @return [Symbol, nil] `:transfer`, `:cash`, `:card`, `:voucher` or `:other`
  # @!attribute payment_date
  #   @return [Date, nil] the payment deadline, not the day it was paid
  # @!attribute appearance
  #   @return [Symbol] `:paper`, `:electronic`, `:edi` or `:unknown`
  # @!attribute periodical_settlement
  #   @return [Boolean]
  # @!attribute small_business
  #   @return [Boolean] the supplier uses the small business tax scheme
  # @!attribute cash_accounting
  #   @return [Boolean] the supplier pays VAT on a cash basis
  # @!attribute self_billing
  #   @return [Boolean] the customer issued the invoice
  # @!attribute utility_settlement
  #   @return [Boolean]
  # @!attribute summary
  #   @return [InvoiceSummary]
  class Invoice
    include Redacted
    include DeepHash

    # Whether this invoice modifies or cancels (storno) another one, given in {#reference}. Its amounts are then the
    # change, with the sign of the change, not the amount to pay. Whether it is a modification or a storno comes
    # from {InvoiceDigest#operation}.
    def modification? = !reference.nil?

    # Leaves out the parties and the amounts.
    def inspect
      "#<data #{self.class.name} invoice_number=#{invoice_number.inspect}, issue_date=#{issue_date.inspect}, " \
        "currency=#{currency.inspect}, modification=#{modification?}>"
    end
  end
end
