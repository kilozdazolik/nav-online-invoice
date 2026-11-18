# frozen_string_literal: true

module NavOnlineInvoice
  InvoiceChainElement = Data.define(:invoice_number, :batch_index, :operation, :supplier_tax_number,
                                    :customer_tax_number, :ins_date, :original_request_version, :max_line_number,
                                    :new_created_lines, :reference)

  # One invoice in a chain: the original invoice or one of its modifications, as listed by {Invoices#chain_digest}.
  #
  # @!attribute operation
  #   @return [Symbol] +:create+, +:modify+ or +:storno+
  # @!attribute ins_date
  #   @return [Time] when NAV received it
  # @!attribute max_line_number
  #   @return [Integer, nil] the highest line number after this modification
  # @!attribute new_created_lines
  #   @return [Array<Range<Integer>>] line numbers this modification added, e.g. +[3..4, 5..5]+
  # @!attribute reference
  #   @return [InvoiceReference, nil] for modifications and storno invoices
  class InvoiceChainElement
    include Redacted

    def initialize(new_created_lines:, **)
      super(new_created_lines: new_created_lines.dup.freeze, **)
    end

    # Shows the invoice's identity only; tax numbers are left out.
    def inspect
      "#<data #{self.class.name} invoice_number=#{invoice_number.inspect}, operation=#{operation.inspect}, " \
        "ins_date=#{ins_date.inspect}>"
    end
  end
end
