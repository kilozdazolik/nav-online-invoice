# frozen_string_literal: true

module NavOnlineInvoice
  # Reads the InvoiceData 3.0 XML of {Invoices#data} into {Invoice} records.
  #
  # @api private
  class InvoiceDataReader
    include AddressReader

    DETAIL_FIELDS = {
      category: [:symbol, "invoiceCategory"], delivery_date: [:date, "invoiceDeliveryDate"],
      delivery_period_start: [:date, "invoiceDeliveryPeriodStart"],
      delivery_period_end: [:date, "invoiceDeliveryPeriodEnd"],
      accounting_delivery_date: [:date, "invoiceAccountingDeliveryDate"], currency: [:text, "currencyCode"],
      exchange_rate: [:decimal, "exchangeRate"], payment_method: [:symbol, "paymentMethod"],
      payment_date: [:date, "paymentDate"], appearance: [:symbol, "invoiceAppearance"],
      periodical_settlement: [:flag, "periodicalSettlement"], small_business: [:flag, "smallBusinessIndicator"],
      cash_accounting: [:flag, "cashAccountingIndicator"], self_billing: [:flag, "selfBillingIndicator"],
      utility_settlement: [:flag, "utilitySettlementIndicator"]
    }.freeze
    RATE_KINDS = {
      "vatPercentage" => :percentage, "vatContent" => :content, "vatExemption" => :exemption,
      "vatOutOfScope" => :out_of_scope, "vatDomesticReverseCharge" => :domestic_reverse_charge,
      "marginSchemeIndicator" => :margin_scheme, "vatAmountMismatch" => :amount_mismatch,
      "noVatCharge" => :no_vat_charge
    }.freeze
    private_constant :DETAIL_FIELDS, :RATE_KINDS

    # @param document [Nokogiri::XML::Document]
    # @param version [String, nil] the format NAV says the invoice was sent in, for the error message
    def initialize(document, version: nil)
      @root = document.root
      @version = version
    end

    # @return [Array<Invoice>] one, or one per invoice of a batch modification in batch order
    # @raise [UnsupportedInvoiceVersionError] if the data is not in the 3.0 format
    def invoices
      check_version!
      main = @root.at_xpath("data:invoiceMain", NAMESPACES)
      batch = main.xpath("data:batchInvoice", NAMESPACES)
      return [invoice(main.at_xpath("data:invoice", NAMESPACES))] if batch.empty?

      batch.map { |node| invoice(node.at_xpath("data:invoice", NAMESPACES), integer(node, "data:batchIndex")) }
           .sort_by(&:batch_index)
    end

    private

    def check_version!
      return if @root&.name == "InvoiceData" && @root.namespace&.href == NAMESPACES["data"]

      raise UnsupportedInvoiceVersionError,
            "the invoice was sent in format #{@version || "unknown"}; only 3.0 can be read, use #document instead"
    end

    def invoice(node, batch_index = nil)
      head = node.at_xpath("data:invoiceHead", NAMESPACES)
      detail = head.at_xpath("data:invoiceDetail", NAMESPACES)
      Invoice.new(
        invoice_number: text(@root, "data:invoiceNumber"), issue_date: date(@root, "data:invoiceIssueDate"),
        completeness_indicator: boolean(@root, "data:completenessIndicator"), batch_index:,
        reference: reference(node.at_xpath("data:invoiceReference", NAMESPACES)), **parties(head),
        **DETAIL_FIELDS.transform_values { |(reader, element)| send(reader, detail, "data:#{element}") },
        summary: summary(node.at_xpath("data:invoiceSummary", NAMESPACES))
      )
    end

    def parties(head)
      buyer = head.at_xpath("data:customerInfo", NAMESPACES)
      representative = head.at_xpath("data:fiscalRepresentativeInfo", NAMESPACES)
      { supplier: supplier(head.at_xpath("data:supplierInfo", NAMESPACES)),
        customer: buyer && customer(buyer),
        fiscal_representative: representative && fiscal_representative(representative) }
    end

    # An optional indicator; NAV leaves it out when it is false.
    def flag(node, xpath) = boolean(node, xpath) || false

    def reference(node)
      node && InvoiceReference.new(
        original_invoice_number: text(node, "data:originalInvoiceNumber"),
        modify_without_master: boolean(node, "data:modifyWithoutMaster"),
        modification_timestamp: nil, modification_index: integer(node, "data:modificationIndex")
      )
    end

    def supplier(node)
      InvoiceParty.new(
        tax_number: tax_number(node, "data:supplierTaxNumber"),
        group_member_tax_number: tax_number(node, "data:groupMemberTaxNumber"),
        community_vat_number: text(node, "data:communityVatNumber"), name: text(node, "data:supplierName"),
        address: address(node.at_xpath("data:supplierAddress", NAMESPACES)),
        bank_account_number: text(node, "data:supplierBankAccountNumber")
      )
    end

    def customer(node)
      vat = node.at_xpath("data:customerVatData", NAMESPACES)
      InvoiceParty.new(
        tax_number: tax_number(vat, "data:customerTaxNumber"),
        group_member_tax_number: tax_number(vat, "data:customerTaxNumber/data:groupMemberTaxNumber"),
        community_vat_number: text(vat, "data:communityVatNumber"),
        third_state_tax_id: text(vat, "data:thirdStateTaxId"), name: text(node, "data:customerName"),
        address: address(node.at_xpath("data:customerAddress", NAMESPACES)),
        bank_account_number: text(node, "data:customerBankAccountNumber"),
        vat_status: symbol(node, "data:customerVatStatus")
      )
    end

    def fiscal_representative(node)
      InvoiceParty.new(
        tax_number: tax_number(node, "data:fiscalRepresentativeTaxNumber"),
        name: text(node, "data:fiscalRepresentativeName"),
        address: address(node.at_xpath("data:fiscalRepresentativeAddress", NAMESPACES)),
        bank_account_number: text(node, "data:fiscalRepresentativeBankAccountNumber")
      )
    end

    def tax_number(node, xpath)
      number = node&.at_xpath(xpath, NAMESPACES)
      number && TaxNumber.format(text(number, "base:taxpayerId"), text(number, "base:vatCode"),
                                 text(number, "base:countyCode"))
    end

    def summary(node)
      normal = node.at_xpath("data:summaryNormal", NAMESPACES)
      gross = node.at_xpath("data:summaryGrossData", NAMESPACES)
      totals = normal ? normal_totals(normal) : simplified_totals(node)
      stated = gross && { gross_amount: decimal(gross, "data:invoiceGrossAmount"),
                          gross_amount_huf: decimal(gross, "data:invoiceGrossAmountHUF") }
      InvoiceSummary.new(simplified: normal.nil?, **totals.merge(stated || {}), gross_calculated: stated.nil?)
    end

    def normal_totals(node)
      net, net_huf, vat, vat_huf = %w[invoiceNetAmount invoiceNetAmountHUF invoiceVatAmount invoiceVatAmountHUF]
                                   .map { |element| decimal(node, "data:#{element}") }
      { net_amount: net, net_amount_huf: net_huf, vat_amount: vat, vat_amount_huf: vat_huf,
        gross_amount: sum(net, vat), gross_amount_huf: sum(net_huf, vat_huf),
        by_vat_rate: node.xpath("data:summaryByVatRate", NAMESPACES).map { |rate| normal_rate(rate) } }
    end

    def simplified_totals(node)
      rates = node.xpath("data:summarySimplified", NAMESPACES).map do |rate|
        VatRateSummary.new(vat_rate: vat_rate(rate.at_xpath("data:vatRate", NAMESPACES)),
                           gross_amount: decimal(rate, "data:vatContentGrossAmount"),
                           gross_amount_huf: decimal(rate, "data:vatContentGrossAmountHUF"))
      end
      { gross_amount: sum(*rates.map(&:gross_amount)), gross_amount_huf: sum(*rates.map(&:gross_amount_huf)),
        by_vat_rate: rates }
    end

    def normal_rate(node)
      VatRateSummary.new(
        vat_rate: vat_rate(node.at_xpath("data:vatRate", NAMESPACES)),
        net_amount: decimal(node, "data:vatRateNetData/data:vatRateNetAmount"),
        net_amount_huf: decimal(node, "data:vatRateNetData/data:vatRateNetAmountHUF"),
        vat_amount: decimal(node, "data:vatRateVatData/data:vatRateVatAmount"),
        vat_amount_huf: decimal(node, "data:vatRateVatData/data:vatRateVatAmountHUF"),
        gross_amount: decimal(node, "data:vatRateGrossData/data:vatRateGrossAmount"),
        gross_amount_huf: decimal(node, "data:vatRateGrossData/data:vatRateGrossAmountHUF")
      )
    end

    # nil if any part is missing, so a total is never made up from part of the data.
    def sum(*amounts)
      amounts.empty? || amounts.include?(nil) ? nil : amounts.sum
    end

    def vat_rate(node)
      form = node.element_children.first
      kind = RATE_KINDS.fetch(form.name)
      case kind
      when :percentage, :content then VatRate.new(kind:, rate: decimal(form, "."))
      when :exemption, :out_of_scope
        VatRate.new(kind:, code: text(form, "data:case"), reason: text(form, "data:reason"))
      when :margin_scheme then VatRate.new(kind:, code: form.text)
      when :amount_mismatch then VatRate.new(kind:, rate: decimal(form, "data:vatRate"), code: text(form, "data:case"))
      else VatRate.new(kind:)
      end
    end
  end
end
