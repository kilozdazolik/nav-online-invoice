# frozen_string_literal: true

module NavOnlineInvoice
  # Queries about submissions to NAV. Use through {Client#transactions}.
  class Transactions
    # The longest pause between two status queries in {#wait}, in seconds.
    MAX_INTERVAL = 15

    # How long NAV may take to store a submission it received (spec 1.9.2), in seconds.
    COMMIT_DELAY = 300

    # @api private
    # @param sleeper [#call] waits between the status queries of {#wait}; for tests
    def initialize(client, sleeper: Kernel.method(:sleep))
      @client = client
      @sleeper = sleeper
    end

    # Asks how NAV processed a submission.
    #
    # @example
    #   status = client.transactions.status(transaction_id)
    #   status&.accepted?
    #   status&.results&.each { |result| puts result.status }
    # @param transaction_id [String] the ID NAV returned for the submission
    # @param return_original_request [Boolean] also return the submitted invoices, decoded
    # @return [TransactionStatus, nil] nil if NAV knows no such transaction
    # @raise [ArgumentError] if the transaction ID is malformed
    # @raise [DecodeError] if a returned original request cannot be decoded
    def status(transaction_id, return_original_request: false)
      @client.execute(Operations::QueryTransactionStatus.new(transaction_id, return_original_request:))
    end

    # Asks for the status until NAV has finished with every item, or until the timeout.
    #
    # The pause between queries starts at +interval+ and grows to at most 15 seconds. It does not wait for
    # annulments to be approved.
    #
    # @example
    #   status = client.transactions.wait(submission.transaction_id, timeout: 120)
    #   if status&.finished? then store(status) else check_again_later end
    # @param transaction_id [String]
    # @param timeout [Numeric] seconds
    # @param interval [Numeric] seconds before the second query
    # @return [TransactionStatus, nil] the last status, finished or not; nil if NAV still knows no such
    #   transaction at the timeout
    # @raise [ArgumentError] if a parameter is invalid
    def wait(transaction_id, timeout: 60, interval: 2)
      check_wait(timeout, interval)
      deadline = Monotonic.now + timeout
      loop do
        current = status(transaction_id)
        remaining = deadline - Monotonic.now
        return current if current&.finished? || remaining <= 0

        @sleeper.call([interval * rand(0.8..1.2), remaining].min)
        interval = [interval * 1.5, MAX_INTERVAL].min
      end
    end

    # Finds out which of the given invoices arrived in a submission that got no answer (spec 1.9.2).
    #
    # Lists the transactions NAV received around `sent_at` and reads their original requests. Call it no earlier
    # than five minutes after `sent_at`, so NAV has stored everything it received. An invoice missing from the
    # result did not arrive, or NAV aborted it, and can be submitted again.
    #
    # @example
    #   rescue NavOnlineInvoice::UnknownOutcomeError => e
    #     # five minutes later:
    #     found = client.transactions.reconcile(sent_at: e.sent_at, invoice_numbers: numbers)
    # @param sent_at [Time] {UnknownOutcomeError#sent_at}
    # @param invoice_numbers [Array<String>] the submitted invoice numbers, or the annulled ones
    # @param annulment [Boolean] look for technical annulments instead of invoices
    # @return [Hash{String => Array<String>}] invoice number => IDs of the transactions that hold it and that NAV
    #   did not abort; more than one ID means it arrived more than once
    # @raise [ArgumentError] if called within five minutes of `sent_at`, or on a {Client#with_predecessor} client
    def reconcile(sent_at:, invoice_numbers:, annulment: false)
      check_reconcile(sent_at)
      wanted = invoice_numbers.map(&:to_s)
      found = Hash.new { |hash, number| hash[number] = [] }
      each_transaction(ins_date: UnknownOutcomeError.reconcile_window(sent_at)) do |transaction|
        next unless transaction.technical_annulment? == annulment

        id = transaction.transaction_id
        (arrived_numbers(id) & wanted).each { |number| found[number] |= [id] }
      end
      found.to_h
    end

    # Lists the submissions NAV received in a time range, one page at a time.
    #
    # Useful to find a transaction ID that was lost, e.g. after a timeout.
    #
    # @example
    #   page = client.transactions.list(ins_date: (Time.now - 86_400)..Time.now)
    #   page.each { |transaction| puts transaction.transaction_id }
    # @param ins_date [Range<Time>] inclusive; at most 840 hours (35 days)
    # @param status [Symbol, nil] +:received+, +:processing+, +:saved+, +:finished+ or +:notified+
    # @param page [Integer]
    # @return [Page<Transaction>]
    # @raise [ArgumentError] if a parameter is invalid
    def list(ins_date:, status: nil, page: 1)
      @client.execute(Operations::QueryTransactionList.new(ins_date:, status:, page:))
    end

    # Walks all pages of {#list}, fetching each page only when it is reached.
    #
    # @param max_pages [Integer, nil] stop after this many pages
    # @yieldparam transaction [Transaction]
    # @return [Enumerator<Transaction>] if no block is given
    def each_transaction(ins_date:, status: nil, max_pages: nil, &)
      Operations::QueryTransactionList.new(ins_date:, status:) # fail on bad parameters before the first request
      items = Paging.items(max_pages) { |page| list(ins_date:, status:, page:) }
      block_given? ? items.each(&) : items
    end

    private

    # Submissions are stored with the successor, whose own client must look for them.
    def check_reconcile(sent_at)
      if @client.predecessor_tax_number
        raise ArgumentError, "reconcile with the client that submitted, not with_predecessor"
      end
      return if @client.config.clock.call - sent_at >= COMMIT_DELAY

      raise ArgumentError, "reconcile no earlier than five minutes after sent_at, so NAV has stored the submission"
    end

    # The invoice or annulled numbers of a transaction that NAV did not abort.
    def arrived_numbers(transaction_id)
      results = status(transaction_id, return_original_request: true)&.results || []
      results.filter_map do |result|
        next if result.aborted? || result.original_request.nil?

        Nokogiri::XML(result.original_request)
                .at_xpath("/*/*[local-name()='invoiceNumber' or local-name()='annulmentReference']")&.text
      end
    end

    def check_wait(timeout, interval)
      raise ArgumentError, "timeout must be a number of 0 or more" unless timeout.is_a?(Numeric) && !timeout.negative?
      raise ArgumentError, "interval must be a positive number" unless interval.is_a?(Numeric) && interval.positive?
    end
  end
end
