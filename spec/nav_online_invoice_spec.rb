# frozen_string_literal: true

require "logger"

RSpec.describe NavOnlineInvoice do
  after { described_class.reset! }

  def configure_globally(**overrides)
    described_class.configure do |config|
      config_attributes(**overrides).each { |key, value| config.public_send(:"#{key}=", value) }
    end
  end

  it "has a semantic version number" do
    expect(NavOnlineInvoice::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "requires a block for configure" do
    expect { described_class.configure }.to raise_error(ArgumentError, /block/)
  end

  it "requires configure before the global client is used" do
    expect { described_class.client }.to raise_error(NavOnlineInvoice::ConfigurationError, /configure/)
  end

  it "builds the global configuration and client" do
    configuration = configure_globally

    expect(described_class.configuration).to be(configuration)
    client = described_class.client

    expect(client.config).to be(configuration)
    expect(described_class.client).to be(client)
  end

  it "replaces the global client when configured again" do
    configure_globally
    first = described_class.client
    configure_globally(environment: :production)

    expect(described_class.client).not_to be(first)
    expect(described_class.client.config.environment).to eq(:production)
  end

  describe ".default_logger" do
    let(:logger) { Logger.new(File::NULL) }

    after { described_class.default_logger = nil }

    it "is the logger of configurations that set none" do
      described_class.default_logger = logger

      expect(build_config.logger).to be(logger)
      expect(configure_globally.logger).to be(logger)
    end

    it "gives way to a logger that is set, or to nil to log nothing" do
      described_class.default_logger = logger
      own = Logger.new(File::NULL)

      expect(build_config(logger: own).logger).to be(own)
      expect(build_config(logger: nil).logger).to be_nil
      expect(configure_globally(logger: nil).logger).to be_nil
    end

    it "is nil unless set" do
      expect(build_config.logger).to be_nil
    end
  end
end
