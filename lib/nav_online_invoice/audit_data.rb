# frozen_string_literal: true

module NavOnlineInvoice
  AuditData = Data.define(:ins_date, :ins_cus_user, :source, :transaction_id, :index, :batch_index,
                          :original_request_version)

  # When and how an invoice reached NAV.
  #
  # @!attribute ins_date
  #   @return [Time]
  # @!attribute ins_cus_user
  #   @return [String] login of the technical user who sent it
  # @!attribute source
  #   @return [Symbol] e.g. +:xml+ or +:web+
  # @!attribute original_request_version
  #   @return [String] the format of the invoice, e.g. "3.0"
  class AuditData
    include Redacted

    # Hides the technical user's login.
    def inspect
      "#<data #{self.class.name} ins_date=#{ins_date.inspect}, ins_cus_user=[FILTERED], source=#{source.inspect}, " \
        "transaction_id=#{transaction_id.inspect}, original_request_version=#{original_request_version.inspect}>"
    end
  end
end
