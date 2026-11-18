# frozen_string_literal: true

module NavOnlineInvoice
  class Configuration
    # Collects settings for {NavOnlineInvoice.configure}.
    #
    # Only the settings that were assigned are passed on, so +throttle = nil+ turns the throttle off.
    class Builder
      include Redacted

      ATTRIBUTES = %i[
        environment login password password_hash signature_key exchange_key tax_number software logger log_payloads
        throttle validate_requests max_retries retry_base_delay open_timeout read_timeout write_timeout clock
        request_id_generator
      ].freeze

      def initialize
        @values = {}
      end

      ATTRIBUTES.each do |name|
        define_method(name) { @values[name] }
        define_method(:"#{name}=") { |value| @values[name] = value }
      end

      # Creates the configuration from the assigned settings.
      #
      # @return [Configuration]
      # @raise [ConfigurationError] if a setting is missing or invalid
      def build
        Configuration.new(**@values)
      rescue ArgumentError => e
        raise ConfigurationError, e.message
      end

      # Shows the assigned setting names only, never their values.
      def inspect
        "#<#{self.class.name} assigned=#{@values.keys.inspect}>"
      end
    end
  end
end
