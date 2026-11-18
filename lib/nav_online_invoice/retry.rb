# frozen_string_literal: true

module NavOnlineInvoice
  # Waits before a retry: exponential backoff with jitter, so many clients do not retry in step.
  #
  # @api private
  module Retry
    module_function

    # @param attempt [Integer] the attempt that failed, from 1
    # @param base_delay [Numeric] seconds before the first retry
    # @param logger [Logger, nil]
    # @param message [String] what failed, for the log
    def wait(attempt, base_delay:, logger:, message:)
      logger&.warn { "NAV #{message}; attempt #{attempt} failed, retrying" }
      seconds = base_delay * (2**(attempt - 1)) * rand(0.8..1.2)
      sleep(seconds) if seconds.positive?
    end
  end
end
