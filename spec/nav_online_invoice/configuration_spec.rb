# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Configuration do
  it "hashes the password and does not keep it" do
    config = build_config

    expect(config.password_hash).to eq(NavOnlineInvoice::Crypto.password_hash("spec-password"))
    expect(config.to_h.values).not_to include("spec-password")
  end

  it "accepts a password hash instead of the password" do
    hash = NavOnlineInvoice::Crypto.password_hash("other").downcase
    config = build_config(password: nil, password_hash: hash)

    expect(config.password_hash).to eq(hash.upcase)
  end

  it "rejects both a password and a password hash" do
    expect { build_config(password_hash: "A" * 128) }
      .to raise_error(NavOnlineInvoice::ConfigurationError, /not both/)
  end

  it "normalizes the tax number and builds the software data" do
    config = build_config(tax_number: "12345678-2-42")

    expect(config.tax_number).to eq("12345678")
    expect(config.software).to be_a(described_class::Software)
    expect(config.software.dev_country_code).to be_nil
  end

  {
    environment: :staging,
    login: "short",
    tax_number: "1234",
    signature_key: " ",
    read_timeout: 0,
    max_retries: -1,
    clock: "now"
  }.each do |key, value|
    it "rejects an invalid #{key}" do
      expect { build_config(key => value) }.to raise_error(NavOnlineInvoice::ConfigurationError, /#{key}/)
    end
  end

  it "rejects invalid software data" do
    expect { build_config(software: ConfigHelpers::SOFTWARE.merge(id: "TOO-SHORT")) }
      .to raise_error(NavOnlineInvoice::ConfigurationError, /software.id/)
    expect { build_config(software: ConfigHelpers::SOFTWARE.merge(operation: :web)) }
      .to raise_error(NavOnlineInvoice::ConfigurationError, /software.operation/)
    expect { build_config(software: ConfigHelpers::SOFTWARE.except(:dev_contact)) }
      .to raise_error(NavOnlineInvoice::ConfigurationError, /dev_contact/)
  end

  it "hides the credentials in inspect" do
    output = build_config.inspect

    expect(output).not_to include("specuser0000001", "spec-signature-key", build_config.password_hash)
    expect(output).to include("login=[FILTERED]", "tax_number=\"12345678\"")
  end

  it "is frozen and validates again on #with" do
    config = build_config

    expect(config).to be_frozen
    expect(config.with(read_timeout: 15).read_timeout).to eq(15)
    expect { config.with(read_timeout: 0) }.to raise_error(NavOnlineInvoice::ConfigurationError)
  end

  it "returns the endpoint of each environment" do
    expect(build_config.endpoint("queryTaxpayer").to_s)
      .to eq("https://api-test.onlineszamla.nav.gov.hu/invoiceService/v3/queryTaxpayer")
    expect(build_config(environment: :production).endpoint("queryTaxpayer").host)
      .to eq("api.onlineszamla.nav.gov.hu")
  end

  describe described_class::Builder do
    it "builds a configuration from the assigned values" do
      builder = described_class.new
      config_attributes.each { |key, value| builder.public_send(:"#{key}=", value) }

      expect(builder.build.login).to eq("specuser0000001")
    end

    it "reports missing values as a configuration error" do
      expect { described_class.new.build }.to raise_error(NavOnlineInvoice::ConfigurationError, /missing/)
    end
  end
end
