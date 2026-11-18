# frozen_string_literal: true

module NavOnlineInvoice
  InvoiceDigest = Data.define(
    :invoice_number, :batch_index, :operation, :category, :issue_date,
    :supplier_tax_number, :supplier_group_member_tax_number, :supplier_name,
    :customer_tax_number, :customer_group_member_tax_number, :customer_name,
    :payment_method, :payment_date, :appearance, :source, :delivery_date, :currency,
    :net_amount, :net_amount_huf, :vat_amount, :vat_amount_huf,
    :transaction_id, :index, :original_invoice_number, :modification_index, :ins_date, :completeness_indicator
  )

  # The main data of one invoice, as listed by {Invoices#digest}.
  #
  # Amounts are BigDecimal, dates Date, timestamps Time (UTC), NAV's codes lowercase Symbols.
  #
  # @!attribute operation
  #   @return [Symbol] +:create+, +:modify+ or +:storno+
  # @!attribute category
  #   @return [Symbol] +:normal+, +:simplified+ or +:aggregate+
  # @!attribute supplier_name
  #   @return [String] personal data if the supplier is a sole trader
  # @!attribute customer_name
  #   @return [String, nil] personal data for private customers and sole traders
  # @!attribute net_amount
  #   @return [BigDecimal, nil] in the invoice's currency
  # @!attribute net_amount_huf
  #   @return [BigDecimal, nil]
  # @!attribute original_invoice_number
  #   @return [String, nil] for modifications: the invoice being modified
  # @!attribute ins_date
  #   @return [Time] when NAV received it
  class InvoiceDigest
    include Redacted

    # Whether the data is the electronic invoice itself (completenessIndicator).
    def complete? = completeness_indicator == true

    # Shows the invoice's identity only; names, tax numbers and amounts are left out.
    def inspect
      "#<data #{self.class.name} invoice_number=#{invoice_number.inspect}, operation=#{operation.inspect}, " \
        "issue_date=#{issue_date.inspect}, ins_date=#{ins_date.inspect}>"
    end
  end
end
