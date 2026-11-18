# frozen_string_literal: true

module NavOnlineInvoice
  class Configuration
    # Checks and normalizes the settings.
    module Validation
      module_function

      def environment(value)
        return value if ENDPOINTS.key?(value)

        raise ConfigurationError, "environment must be :test or :production, got #{value.inspect}"
      end

      def login(value)
        return value if value.is_a?(String) && value.match?(/\A[a-zA-Z0-9]{6,15}\z/)

        raise ConfigurationError, "login must be 6-15 letters or digits"
      end

      def password_hash(password, hash)
        raise ConfigurationError, "give either password or password_hash, not both" if password && hash
        return Crypto.password_hash(required(:password, password)) if password

        hash = required(:password_hash, hash).upcase
        return hash if hash.match?(/\A[0-9A-F]{128}\z/)

        raise ConfigurationError, "password_hash must be a SHA-512 hex digest"
      end

      def exchange_key(value)
        return value if value.nil? || (value.is_a?(String) && value.bytesize == 16 && !value.strip.empty?)

        raise ConfigurationError, "exchange_key must be 16 characters"
      end

      def tax_number(value)
        TaxNumber.normalize(value)
      rescue ArgumentError
        raise ConfigurationError, "tax_number must have 8 or 11 digits, got #{value.inspect}"
      end

      def software(value)
        software = value.is_a?(Hash) ? Software.new(**value) : value
        raise ConfigurationError, "software must be a Hash or Configuration::Software" unless software.is_a?(Software)

        software_id(software.id)
        software_operation(software.operation)
        %i[name main_version dev_name dev_contact].each do |key|
          required(:"software.#{key}", software.public_send(key))
        end
        software
      rescue ArgumentError => e
        raise ConfigurationError, "software: #{e.message}"
      end

      def software_id(value)
        return if value.is_a?(String) && value.match?(/\A[0-9A-Z-]{18}\z/)

        raise ConfigurationError, "software.id must be exactly 18 characters of 0-9, A-Z and -"
      end

      def software_operation(value)
        return if %i[local_software online_service].include?(value)

        raise ConfigurationError, "software.operation must be :local_software or :online_service"
      end

      def required(name, value)
        return value if value.is_a?(String) && !value.strip.empty?

        raise ConfigurationError, "#{name} is required"
      end

      def non_negative_integer(name, value)
        return value if value.is_a?(Integer) && !value.negative?

        raise ConfigurationError, "#{name} must be an integer of 0 or more"
      end

      def non_negative_number(name, value)
        return value if value.is_a?(Numeric) && !value.negative?

        raise ConfigurationError, "#{name} must be a number of 0 or more"
      end

      def positive_number(name, value)
        return value if value.is_a?(Numeric) && value.positive?

        raise ConfigurationError, "#{name} must be a positive number"
      end

      def callable(name, value)
        return value if value.respond_to?(:call)

        raise ConfigurationError, "#{name} must respond to call"
      end
    end
    private_constant :Validation
  end
end
