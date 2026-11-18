# frozen_string_literal: true

module NavOnlineInvoice
  # Rails integration, loaded only when Rails is present.
  #
  # Uses the Rails logger unless a configuration sets its own, and turns `config.nav_online_invoice` into the
  # global configuration. It reads no credentials or environment variables: the application passes the values in.
  #
  # @example config/application.rb
  #   config.nav_online_invoice.environment = :production
  #   config.nav_online_invoice.login = Rails.application.credentials.dig(:nav, :login)
  class Railtie < ::Rails::Railtie
    SECRETS = %i[login password password_hash signature_key exchange_key].freeze
    private_constant :SECRETS

    config.nav_online_invoice = ActiveSupport::OrderedOptions.new

    initializer "nav_online_invoice.logger", after: :initialize_logger do
      NavOnlineInvoice.default_logger ||= ::Rails.logger
    end

    # Before config/initializers, so an initializer can still call NavOnlineInvoice.configure itself.
    initializer "nav_online_invoice.configure", before: :load_config_initializers do |app|
      Railtie.configure(app.config.nav_online_invoice)
    end

    # Sets the global configuration from `config.nav_online_invoice`; does nothing if it is empty.
    #
    # @param options [ActiveSupport::OrderedOptions]
    # @return [Configuration, nil]
    # @raise [ConfigurationError] if a setting is unknown or invalid
    def self.configure(options)
      return if options.empty?

      unknown = options.keys.map(&:to_sym) - Configuration::Builder::ATTRIBUTES
      raise ConfigurationError, "unknown config.nav_online_invoice settings: #{unknown.inspect}" unless unknown.empty?

      configuration = NavOnlineInvoice.configure do |config|
        options.each { |name, value| config.public_send(:"#{name}=", value) }
      end
      hide_secrets(options)
      configuration
    end

    # The configuration keeps only the password hash and hides the keys; the Rails config would otherwise keep
    # them in plain text for anyone who inspects it.
    def self.hide_secrets(options)
      SECRETS.each { |name| options[name] = Redactor::FILTERED if options.key?(name) }
    end
    private_class_method :hide_secrets
  end
end
