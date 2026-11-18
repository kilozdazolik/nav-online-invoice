# frozen_string_literal: true

module NavOnlineInvoice
  # Queries about submissions to NAV. Use through {Client#transactions}.
  class Transactions
    # The longest pause between two status queries in {#wait}, in seconds.
    MAX_INTERVAL = 15

    # @api private
    def initialize(client)
      @client = client
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

        sleep([interval * rand(0.8..1.2), remaining].min)
        interval = [interval * 1.5, MAX_INTERVAL].min
      end
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
      items = Paging.items(max_pages) { |page| list(ins_date:, status:, page:) }
      block_given? ? items.each(&) : items
    end

    private

    def check_wait(timeout, interval)
      raise ArgumentError, "timeout must be a number of 0 or more" unless timeout.is_a?(Numeric) && !timeout.negative?
      raise ArgumentError, "interval must be a positive number" unless interval.is_a?(Numeric) && interval.positive?
    end
  end
end
