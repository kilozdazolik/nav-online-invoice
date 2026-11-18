# frozen_string_literal: true

module NavOnlineInvoice
  # The service metrics NAV publishes, as returned by {Metrics#all}.
  #
  # @!attribute updated_at
  #   @return [Time, nil] when NAV last refreshed them
  # @!attribute metrics
  #   @return [Array<Metric>]
  ServiceMetrics = Data.define(:updated_at, :metrics)
end
