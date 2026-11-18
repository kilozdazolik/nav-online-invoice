# frozen_string_literal: true

module NavOnlineInvoice
  Transaction = Data.define(:transaction_id, :ins_date, :ins_cus_user, :source, :status, :technical_annulment,
                            :original_request_version, :item_count)

  # A submission to NAV (invoices or annulments), as listed by {Transactions#list}.
  #
  # @!attribute ins_date
  #   @return [Time] when NAV received it
  # @!attribute ins_cus_user
  #   @return [String] login of the technical user who sent it
  # @!attribute source
  #   @return [Symbol] e.g. +:xml+ (machine interface) or +:web+
  # @!attribute status
  #   @return [Symbol] +:received+, +:processing+, +:saved+, +:finished+ or +:notified+
  # @!attribute technical_annulment
  #   @return [Boolean] whether it is a technical annulment
  # @!attribute original_request_version
  #   @return [String] e.g. "3.0"
  # @!attribute item_count
  #   @return [Integer] number of invoices or annulments in it
  class Transaction
    include Redacted

    # Hides the technical user's login.
    def inspect
      "#<data #{self.class.name} transaction_id=#{transaction_id.inspect}, ins_date=#{ins_date.inspect}, " \
        "ins_cus_user=[FILTERED], status=#{status.inspect}, item_count=#{item_count.inspect}>"
    end
  end
end
