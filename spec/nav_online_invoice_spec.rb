# frozen_string_literal: true

RSpec.describe NavOnlineInvoice do
  after do
    described_class.instance_variable_set(:@configuration, nil)
    described_class.instance_variable_set(:@client, nil)
  end

  def configure_globally(**overrides)
    described_class.configure do |config|
      config_attributes(**overrides).each { |key, value| config.public_send(:"#{key}=", value) }
    end
  end

  it "has a semantic version number" do
    expect(NavOnlineInvoice::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
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
end
