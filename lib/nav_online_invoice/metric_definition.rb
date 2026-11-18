# frozen_string_literal: true

module NavOnlineInvoice
  # What a service metric measures.
  #
  # @!attribute name
  #   @return [String] e.g. "responseTimeAverageMsManageInvoice"
  # @!attribute type
  #   @return [Symbol] `:counter`, `:gauge`, `:histogram` or `:summary`
  # @!attribute descriptions
  #   @return [Hash{Symbol => String}] by language: `:hu`, `:en` and `:de`
  MetricDefinition = Data.define(:name, :type, :descriptions)
end
