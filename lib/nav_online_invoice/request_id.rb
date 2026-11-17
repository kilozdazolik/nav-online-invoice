# frozen_string_literal: true

module NavOnlineInvoice
  # Default generator for request IDs.
  #
  # NAV requires a new, unique ID for every request, at most 30 characters of [+a-zA-Z0-9_]. The ID
  # is made of a prefix, the current time in milliseconds (base 36) and a random part.
  #
  # Any object that responds to +call+ can replace it, see {Configuration#request_id_generator}.
  module RequestId
    module_function

    # @param prefix [String]
    # @return [String]
    def call(prefix: "NOI")
      "#{prefix}#{Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond).to_s(36).upcase}" \
        "#{SecureRandom.hex(4).upcase}"
    end
  end
end
