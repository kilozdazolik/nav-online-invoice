# frozen_string_literal: true

module NavOnlineInvoice
  TransactionStatus = Data.define(:request_id, :results, :original_request_version, :annulment_verification_status,
                                  :annulment_decision_date, :annulment_decision_user, :raw_xml)

  # The processing state of a submission, as returned by {Transactions#status}.
  #
  # @!attribute results
  #   @return [Array<ProcessingResult>] one per invoice or annulment, in submission order
  # @!attribute original_request_version
  #   @return [String] e.g. "3.0"
  # @!attribute annulment_verification_status
  #   @return [Symbol, nil] for annulments only: +:not_verifiable+, +:verification_pending+,
  #     +:verification_done+ or +:verification_rejected+
  # @!attribute annulment_decision_user
  #   @return [String, nil] login of the user who decided on the annulment
  class TransactionStatus
    def initialize(request_id:, results:, original_request_version:, annulment_verification_status:,
                   annulment_decision_date:, annulment_decision_user:, raw_xml:)
      super(request_id:, results: results.dup.freeze, original_request_version:, annulment_verification_status:,
            annulment_decision_date:, annulment_decision_user:, raw_xml:)
    end

    # Whether NAV processed every item without errors. For an annulment this does not mean it took effect: see
    # {#annulment_pending?} and {#annulled?}.
    def accepted?
      results.all? { |result| result.done? && !result.errors? }
    end

    # Whether the annulments wait for approval on NAV's web interface.
    def annulment_pending?
      annulment_verification_status == :verification_pending
    end

    # Whether a user approved the annulments, so the invoices are annulled.
    def annulled?
      annulment_verification_status == :verification_done
    end

    # Leaves out the raw XML and the decision user's login.
    def inspect
      "#<data #{self.class.name} request_id=#{request_id.inspect}, results=#{results.inspect}, " \
        "annulment_verification_status=#{annulment_verification_status.inspect}>"
    end
    alias to_s inspect

    # Used by +pp+, IRB and the Rails console.
    def pretty_print(printer)
      printer.text(inspect)
    end
  end
end
