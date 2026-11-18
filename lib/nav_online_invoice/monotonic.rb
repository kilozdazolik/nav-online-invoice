# frozen_string_literal: true

module NavOnlineInvoice
  # Elapsed time that a wrong or jumping system clock cannot disturb.
  #
  # @api private
  module Monotonic
    # @return [Float] seconds since an arbitrary point
    def self.now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
