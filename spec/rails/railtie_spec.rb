# frozen_string_literal: true

begin
  require "rails"
rescue LoadError
  # Rails is not in this bundle; these specs run with gemfiles/rails_8_1.gemfile.
end

if defined?(Rails::Railtie)
  require "logger"
  require "stringio"
  require "tmpdir"
  require "nav_online_invoice/railtie"

  module RailtieSpec
    # A minimal application, initialized once for this file.
    class Application < Rails::Application
      config.root = Dir.mktmpdir
      config.eager_load = false
      config.logger = Logger.new(StringIO.new)
      config.secret_key_base = "0" * 64
    end
  end

  RSpec.describe NavOnlineInvoice::Railtie do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll -- a Rails application can be initialized only once
      app = RailtieSpec::Application
      config_attributes.except(:throttle).each { |name, value| app.config.nav_online_invoice[name] = value }
      app.initialize!
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      NavOnlineInvoice.reset!
      NavOnlineInvoice.default_logger = nil
    end

    it "uses the Rails logger by default" do
      expect(NavOnlineInvoice.default_logger).to be(Rails.logger)
      expect(build_config.logger).to be(Rails.logger)
    end

    it "keeps a logger the configuration sets, or nil" do
      own = Logger.new(File::NULL)

      expect(build_config(logger: own).logger).to be(own)
      expect(build_config(logger: nil).logger).to be_nil
    end

    it "builds the global configuration from config.nav_online_invoice" do
      expect(NavOnlineInvoice.configuration).to have_attributes(environment: :test, tax_number: "12345678",
                                                                logger: Rails.logger)
    end

    it "hides the secrets in config.nav_online_invoice once it is applied" do
      options = RailtieSpec::Application.config.nav_online_invoice

      expect(options.values_at(:login, :password, :signature_key, :exchange_key)).to all(eq("[FILTERED]"))
      expect(options[:tax_number]).to eq("12345678")
    end

    describe ".configure" do
      after { NavOnlineInvoice.reset! }

      it "does nothing for empty settings" do
        NavOnlineInvoice.reset!

        expect(described_class.configure(ActiveSupport::OrderedOptions.new)).to be_nil
        expect { NavOnlineInvoice.configuration }.to raise_error(NavOnlineInvoice::ConfigurationError)
      end

      it "rejects unknown and invalid settings" do
        unknown = ActiveSupport::OrderedOptions.new.merge!(config_attributes(colour: :red))
        invalid = ActiveSupport::OrderedOptions.new.merge!(config_attributes(environment: :staging))

        expect { described_class.configure(unknown) }.to raise_error(NavOnlineInvoice::ConfigurationError, /colour/)
        expect { described_class.configure(invalid) }.to raise_error(NavOnlineInvoice::ConfigurationError)
      end
    end
  end
end
