# frozen_string_literal: true

module NavOnlineInvoice
  # Keeps at least +interval+ seconds between requests.
  #
  # NAV allows one request per second per IP address on some operations and delays the rest. The
  # default instance is shared by every client in the process. If several processes share one IP
  # address, pass your own object with a +wait(operation_name)+ method, e.g. one backed by a
  # database lock.
  class Throttle
    # @return [Throttle] the instance shared by all clients in this process
    def self.default
      DEFAULT
    end

    # @param interval [Numeric] seconds between two requests
    def initialize(interval: 1.0, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                   sleeper: ->(seconds) { sleep(seconds) })
      @interval = interval
      @clock = clock
      @sleeper = sleeper
      @mutex = Mutex.new
      @next_at = nil
    end

    # Blocks until the next request may be sent.
    #
    # @param _operation_name [String] the NAV operation, for throttles that limit per operation
    # @return [void]
    def wait(_operation_name = nil)
      @mutex.synchronize do
        now = @clock.call
        if @next_at && now < @next_at
          @sleeper.call(@next_at - now)
          now = @next_at
        end
        @next_at = now + @interval
      end
      nil
    end

    DEFAULT = new
    private_constant :DEFAULT
  end
end
