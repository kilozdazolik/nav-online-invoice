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

    # Leaves out the invoice, which holds names, addresses and amounts.
    def inspect
      "#<data #{self.class.name} request_id=#{request_id.inspect}, compressed=#{compressed.inspect}, " \
        "audit_data=#{audit_data.inspect}>"
    end
  end
end
