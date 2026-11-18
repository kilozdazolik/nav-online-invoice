# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # The search conditions of queryInvoiceDigest: checked on creation, written as invoiceQueryParams.
    class InvoiceQueryParams
      MANDATORY = %i[issue_date ins_date original_invoice_number].freeze

      # Filter keyword => [NAV element, allowed values]; in the order the schema requires.
      ADDITIONAL = {
        tax_number: ["taxNumber"],
        group_member_tax_number: ["groupMemberTaxNumber"],
        name: ["name"],
        category: ["invoiceCategory", %w[NORMAL SIMPLIFIED AGGREGATE]],
        payment_method: ["paymentMethod", %w[TRANSFER CASH CARD VOUCHER OTHER]],
        appearance: ["invoiceAppearance", %w[PAPER ELECTRONIC EDI UNKNOWN]],
        source: ["source", %w[WEB XML MGM OPG OSZ]],
        currency: ["currency"]
      }.freeze

      # Filter keyword => [NAV element, value kind]; in the order the schema requires.
      RELATIONAL = {
        delivery_date: ["invoiceDelivery", :date],
        payment_date: ["paymentDate", :date],
        net_amount: ["invoiceNetAmount", :amount],
        net_amount_huf: ["invoiceNetAmountHUF", :amount],
        vat_amount: ["invoiceVatAmount", :amount],
        vat_amount_huf: ["invoiceVatAmountHUF", :amount]
      }.freeze

      TRANSACTION = %i[transaction_id index operation].freeze
      FILTERS = (MANDATORY + ADDITIONAL.keys + RELATIONAL.keys + TRANSACTION).freeze
      private_constant :MANDATORY, :ADDITIONAL, :RELATIONAL, :TRANSACTION

      # @param filters [Hash] see {Invoices#digest}
      # @raise [ArgumentError]
      def initialize(filters)
        unknown = filters.keys - FILTERS
        raise ArgumentError, "unknown filter: #{unknown.join(", ")}" unless unknown.empty?

        @mandatory = mandatory(filters)
        @additional = additional(filters)
        @relational = relational(filters)
        @transaction = transaction(filters)
      end

      # @param xml [Nokogiri::XML::Builder]
      def build(xml)
        xml.invoiceQueryParams do
          build_mandatory(xml)
          build_list(xml, :additionalQueryParams, @additional)
          build_list(xml, :relationalQueryParams, @relational)
          build_list(xml, :transactionQueryParams, @transaction)
        end
      end

      private

      def mandatory(filters)
        given = MANDATORY.select { |key| filters.key?(key) }
        raise ArgumentError, "give exactly one of #{MANDATORY.join(", ")}" unless given.size == 1

        key = given.first
        value = filters[key]
        case key
        when :issue_date
          from, to = Params.date_range(key, value)
          [:invoiceIssueDate, [["dateFrom", from.iso8601], ["dateTo", to.iso8601]]]
        when :ins_date
          from, to = Params.time_range(key, value)
          [:insDate, [["dateTimeFrom", Params.timestamp(from)], ["dateTimeTo", Params.timestamp(to)]]]
        else [:originalInvoiceNumber, Params.text(key, value, max: 50)]
        end
      end

      def additional(filters)
        ADDITIONAL.filter_map do |key, (element, allowed)|
          [element, additional_value(key, filters[key], allowed)] if filters.key?(key)
        end
      end

      def additional_value(key, value, allowed)
        case key
        when :tax_number, :group_member_tax_number then Params.tax_number(key, value)
        when :name then Params.text(key, value, min: 5, max: 512)
        when :currency then currency(value)
        else Params.enum(key, value, allowed)
        end
      end

      def currency(value)
        code = value.to_s.upcase
        return code if code.match?(/\A[A-Z]{3}\z/)

        raise ArgumentError, "currency must be a 3-letter ISO code, got #{value.inspect}"
      end

      def relational(filters)
        RELATIONAL.flat_map do |key, (element, kind)|
          next [] unless filters.key?(key)

          Params.relational(key, filters[key], kind).map { |operator, value| [element, operator, value] }
        end
      end

      def transaction(filters)
        return no_transaction(filters) unless filters.key?(:transaction_id)

        entries = [["transactionId", Params.transaction_id(filters[:transaction_id])]]
        entries << ["index", Params.index(:index, filters[:index])] if filters.key?(:index)
        if filters.key?(:operation)
          entries << ["invoiceOperation", Params.enum(:operation, filters[:operation], Params::INVOICE_OPERATIONS)]
        end
        entries
      end

      def no_transaction(filters)
        orphans = (TRANSACTION - [:transaction_id]) & filters.keys
        raise ArgumentError, "#{orphans.join(", ")} needs transaction_id" unless orphans.empty?

        []
      end

      def build_mandatory(xml)
        element, value = @mandatory
        xml.mandatoryQueryParams do
          if value.is_a?(Array)
            xml.public_send(element) { value.each { |name, part| xml.public_send(name, part) } }
          else
            xml.public_send(element, value)
          end
        end
      end

      # Entries are [element, value] or, for relational conditions, [element, operator, value].
      def build_list(xml, wrapper, entries)
        return if entries.empty?

        xml.public_send(wrapper) do
          entries.each do |element, *values|
            next xml.public_send(element, values.first) if values.size == 1

            xml.public_send(element) do
              xml.queryOperator values.first
              xml.queryValue values.last
            end
          end
        end
      end
    end
  end
end
