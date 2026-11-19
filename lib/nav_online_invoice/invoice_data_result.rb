# frozen_string_literal: true

module NavOnlineInvoice
  InvoiceDataResult = Data.define(:request_id, :invoice_xml, :compressed, :audit_data, :electronic_invoice_hash,
                                  :raw_xml)

  # The full data of one invoice, as returned by {Invoices#data}.
  #
  # @!attribute invoice_xml
  #   @return [String] the invoice in NAV's InvoiceData format, in the version it was submitted in
  # @!attribute audit_data
  #   @return [AuditData]
  # @!attribute electronic_invoice_hash
  #   @return [ElectronicInvoiceHash, nil] for electronic invoices
  # @!attribute compressed
  #   @return [Boolean] whether NAV received the invoice gzipped
  # @!attribute raw_xml
  #   @return [String] NAV's answer; it can hold names, addresses and invoice contents, so do not log it
  class InvoiceDataResult
    include Redacted

    # Parses {#invoice_xml}. Parsed again on each call; keep the result if you need it more than once.
    #
    # @return [Nokogiri::XML::Document]
    def document
      Nokogiri::XML(invoice_xml) { |config| config.strict.nonet }
    end

    # Reads the invoice into a record. Read again on each call; keep the result if you need it more than once.
    #
    # @example
    #   invoice = client.invoices.data("INV-2026-0001", direction: :inbound)&.invoice
    #   invoice&.supplier&.bank_account_number
    # @return [Invoice]
    # @raise [ArgumentError] if the data is a batch modification of several invoices; use {#invoices}
    # @raise [UnsupportedInvoiceVersionError] if the invoice was sent in a format older than 3.0
    def invoice
      list = invoices
      return list.first if list.one?

      raise ArgumentError, "the data holds #{list.size} invoices of a batch modification; use #invoices"
    end

    # Reads every invoice: one, or each invoice of a batch modification in batch order.
    #
    # @return [Array<Invoice>]
    # @raise [UnsupportedInvoiceVersionError] if the invoice was sent in a format older than 3.0
    def invoices
      InvoiceDataReader.new(document, version: audit_data&.original_request_version).invoices
    end

    # Leaves out the invoice, which holds names, addresses and amounts.
    def inspect
      "#<data #{self.class.name} request_id=#{request_id.inspect}, compressed=#{compressed.inspect}, " \
        "audit_data=#{audit_data.inspect}>"
    end
  end
end
