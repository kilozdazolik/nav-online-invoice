# frozen_string_literal: true

module NavOnlineInvoice
  ProcessingResult = Data.define(:index, :batch_index, :status, :technical_validation_messages,
                                 :business_validation_messages, :compressed, :original_request)

  # How NAV processed one invoice or annulment of a submission.
  #
  # @!attribute index
  #   @return [Integer] the position of the invoice in the submission, starting at 1
  # @!attribute status
  #   @return [Symbol] +:received+, +:processing+, +:saved+, +:done+ or +:aborted+
  # @!attribute technical_validation_messages
  #   @return [Array<ApiError::TechnicalValidationMessage>]
  # @!attribute business_validation_messages
  #   @return [Array<BusinessValidationMessage>]
  # @!attribute original_request
  #   @return [String, nil] the submitted invoice XML, decoded; only if it was asked for
  class ProcessingResult
    include Redacted

    def initialize(index:, batch_index:, status:, technical_validation_messages:, business_validation_messages:,
                   compressed:, original_request:)
      super(index:, batch_index:, status:, compressed:, original_request:,
            technical_validation_messages: technical_validation_messages.dup.freeze,
            business_validation_messages: business_validation_messages.dup.freeze)
    end

    # Whether NAV finished processing the invoice. Accepted only if {#errors?} is false too.
    def done?
      status == :done
    end

    def aborted?
      status == :aborted
    end

    # Whether NAV finished with this item, either way.
    def final?
      done? || aborted?
    end

    # Whether NAV is still processing this item.
    def pending?
      !final?
    end

    # Whether NAV reported a technical error or a business error (warnings do not count).
    def errors?
      technical_validation_messages.any? || business_validation_messages.any? { |m| m.result_code == :error }
    end

    # Leaves out the submitted invoice.
    def inspect
      "#<data #{self.class.name} index=#{index}, status=#{status.inspect}, " \
        "technical_validation_messages=#{technical_validation_messages.size}, " \
        "business_validation_messages=#{business_validation_messages.size}>"
    end
  end
end
