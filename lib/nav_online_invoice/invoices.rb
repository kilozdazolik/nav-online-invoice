# frozen_string_literal: true

module NavOnlineInvoice
  # Invoice queries and submissions. Use through {Client#invoices}.
  class Invoices
    # @api private
    def initialize(client)
      @client = client
    end

    # Lists invoices issued by you (+:outbound+) or to you (+:inbound+), one page of up to 100 at a time.
    #
    # Give exactly one of +issue_date+, +ins_date+ and +original_invoice_number+. All filters must match.
    #
    # @example
    #   page = client.invoices.digest(direction: :outbound, issue_date: Date.new(2026, 11, 1)..Date.new(2026, 11, 30),
    #                                 net_amount: 10_000..500_000)
    #   page.each { |invoice| puts "#{invoice.invoice_number} #{invoice.net_amount_huf}" }
    # @param direction [Symbol] +:outbound+ or +:inbound+
    # @param page [Integer]
    # @option filters [Range<Date>] :issue_date at most 35 days
    # @option filters [Range<Time>] :ins_date when NAV received them; inclusive, at most 840 hours
    # @option filters [String] :original_invoice_number the invoice and all its modifications
    # @option filters [String] :tax_number the other party (customer if outbound, supplier if inbound)
    # @option filters [String] :group_member_tax_number
    # @option filters [String] :name the other party's name, starting with this; at least 5 characters
    # @option filters [Symbol] :category +:normal+, +:simplified+ or +:aggregate+
    # @option filters [Symbol] :payment_method +:transfer+, +:cash+, +:card+, +:voucher+ or +:other+
    # @option filters [Symbol] :appearance +:paper+, +:electronic+, +:edi+ or +:unknown+
    # @option filters [Symbol] :source +:web+, +:xml+, +:mgm+, +:opg+ or +:osz+
    # @option filters [String] :currency ISO code, e.g. "EUR"
    # @option filters [Date, Range<Date>] :delivery_date a day, or a range with both ends
    # @option filters [Date, Range<Date>] :payment_date
    # @option filters [Numeric, Range] :net_amount an amount, or a range with both ends; same for the next three
    # @option filters [Numeric, Range] :net_amount_huf
    # @option filters [Numeric, Range] :vat_amount
    # @option filters [Numeric, Range] :vat_amount_huf
    # @option filters [String] :transaction_id invoices of one submission
    # @option filters [Integer] :index with +transaction_id+: the invoice's position in it
    # @option filters [Symbol] :operation with +transaction_id+: +:create+, +:modify+ or +:storno+
    # @return [Page<InvoiceDigest>]
    # @raise [ArgumentError] if a parameter is invalid
    def digest(direction:, page: 1, **filters)
      @client.execute(Operations::QueryInvoiceDigest.new(direction:, page:, **filters))
    end

    # Walks all pages of {#digest}, fetching each page only when it is reached.
    #
    # NAV's data can change between pages, e.g. when new invoices arrive.
    #
    # @param max_pages [Integer, nil] stop after this many pages
    # @yieldparam invoice [InvoiceDigest]
    # @return [Enumerator<InvoiceDigest>] if no block is given
    def each_digest(direction:, max_pages: nil, **filters, &)
      Operations::QueryInvoiceDigest.new(direction:, **filters) # fail on bad filters before the first request
      items = Paging.items(max_pages) { |page| digest(direction:, page:, **filters) }
      block_given? ? items.each(&) : items
    end

    # Lists an invoice and all its modifications, one page at a time.
    #
    # The original invoice need not exist at NAV; modifications that refer to the number are listed anyway.
    #
    # @example
    #   client.invoices.chain_digest("INV-2026-0001", direction: :outbound).each do |element|
    #     puts "#{element.operation} #{element.invoice_number}"
    #   end
    # @param invoice_number [String] the original invoice
    # @param direction [Symbol] +:outbound+ or +:inbound+
    # @param tax_number [String, nil] the other party's tax number
    # @param page [Integer]
    # @return [Page<InvoiceChainElement>]
    # @raise [ArgumentError] if a parameter is invalid
    def chain_digest(invoice_number, direction:, tax_number: nil, page: 1)
      @client.execute(Operations::QueryInvoiceChainDigest.new(invoice_number, direction:, tax_number:, page:))
    end

    # Walks all pages of {#chain_digest}, fetching each page only when it is reached.
    #
    # @param max_pages [Integer, nil] stop after this many pages
    # @yieldparam element [InvoiceChainElement]
    # @return [Enumerator<InvoiceChainElement>] if no block is given
    def each_chain_element(invoice_number, direction:, tax_number: nil, max_pages: nil, &)
      Operations::QueryInvoiceChainDigest.new(invoice_number, direction:, tax_number:)
      items = Paging.items(max_pages) { |page| chain_digest(invoice_number, direction:, tax_number:, page:) }
      block_given? ? items.each(&) : items
    end

    # Asks whether an invoice number is valid at NAV, i.e. exists exactly once.
    #
    # @example
    #   client.invoices.check("INV-2026-0001", direction: :outbound) # => true
    # @param invoice_number [String]
    # @param direction [Symbol] +:outbound+ (issued by you) or +:inbound+ (received)
    # @param batch_index [Integer, nil] the invoice within a batch modification
    # @param supplier_tax_number [String, nil] only with +:inbound+
    # @return [Boolean]
    # @raise [ArgumentError] if a parameter is invalid
    def check(invoice_number, direction:, batch_index: nil, supplier_tax_number: nil)
      @client.execute(Operations::QueryInvoiceCheck.new(invoice_number, direction:, batch_index:,
                                                                        supplier_tax_number:))
    end

    # Fetches the full data of one invoice.
    #
    # @example
    #   result = client.invoices.data("INV-2026-0001", direction: :outbound)
    #   result&.document&.at_xpath("//data:invoiceNumber", "data" => "http://schemas.nav.gov.hu/OSA/3.0/data")
    # @param (see #check)
    # @return [InvoiceDataResult, nil] nil if NAV has no such invoice for you
    # @raise [ArgumentError] if a parameter is invalid
    # @raise [DecodeError] if the invoice data cannot be decoded
    def data(invoice_number, direction:, batch_index: nil, supplier_tax_number: nil)
      @client.execute(Operations::QueryInvoiceData.new(invoice_number, direction:, batch_index:,
                                                                       supplier_tax_number:))
    end

    # Submits up to 100 finished invoices to NAV.
    #
    # Each call requests its own exchange token and sends the invoices once; it never retries. A NAV error means
    # nothing was stored, so the invoices can be sent again. {UnknownOutcomeError} means they may have arrived:
    # do not resend them before {Transactions#reconcile} says they did not.
    #
    # @example
    #   submission = client.invoices.submit([{ operation: :create, xml: invoice_xml }])
    #   status = client.transactions.wait(submission.transaction_id)
    #   status.accepted?
    # @param items [Array<Hash>] in index order, each with:
    #   +:operation+ (+:create+, +:modify+ or +:storno+), +:xml+ (the InvoiceData XML) and optionally
    #   +:electronic_invoice_hash+ (+{ value:, crypto_type: "SHA3-512" or "SHA-256" }+, the hash of your own
    #   electronic invoice file; computed by the gem when the XML has completenessIndicator true)
    # @param compress [Boolean, :auto] gzip the invoices; +:auto+ only when the request would be too large
    # @return [Submission]
    # @raise [ConfigurationError] if the configuration has no exchange_key
    # @raise [ArgumentError, SchemaValidationError, SubmissionTooLargeError] before any request is sent
    # @raise [UnknownOutcomeError] if no answer arrived
    def submit(items, compress: :auto)
      exchange_key = exchange_key!
      prepared, compressed = SubmissionItems.prepare(items, compress:, validate: @client.config.validate_requests)
      with_token(exchange_key) { |token| Operations::ManageInvoice.new(token:, items: prepared, compressed:) }
    end

    # Asks NAV to annul up to 100 invoices or modifications that were submitted with wrong data.
    #
    # A technical annulment takes effect only after a user approves it on NAV's web interface; until then
    # {TransactionStatus#annulment_pending?} is true. Sent once, like {#submit}, with the same errors.
    #
    # @example
    #   submission = client.invoices.annul([{ reference: "INV-2026-0001", code: :erratic_data,
    #                                         reason: "Sent with a wrong customer" }])
    # @param items [Array<Hash>] in index order, each with:
    #   +:reference+ (the invoice or modification number), +:code+ (+:erratic_data+, +:erratic_invoice_number+,
    #   +:erratic_invoice_issue_date+ or +:erratic_electronic_hash_value+), +:reason+ (up to 1024 characters) and
    #   optionally +:timestamp+ (a Time, now by default)
    # @return [Submission]
    # @raise [ConfigurationError] if the configuration has no exchange_key
    # @raise [ArgumentError, SchemaValidationError] before any request is sent
    # @raise [UnknownOutcomeError] if no answer arrived
    def annul(items)
      exchange_key = exchange_key!
      prepared = AnnulmentItems.prepare(items, time: @client.config.clock.call,
                                               validate: @client.config.validate_requests)
      with_token(exchange_key) { |token| Operations::ManageAnnulment.new(token:, items: prepared) }
    end

    private

    def exchange_key!
      @client.config.exchange_key or raise ConfigurationError, "exchange_key is required to submit to NAV"
    end

    # Requests a token and sends the operation built with it. A token that expired while the request waited for the
    # throttle is replaced once; nothing was sent with it.
    def with_token(exchange_key)
      renewed = false
      begin
        @client.execute(yield(@client.execute(Operations::TokenExchange.new(exchange_key))))
      rescue ExchangeTokenError => e
        raise if e.code || renewed

        renewed = true
        retry
      end
    end
  end
end
