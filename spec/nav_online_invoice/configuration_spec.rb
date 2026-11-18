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
    clock: "now",
    exchange_key: "too-short"
  }.each do |key, value|
    it "rejects an invalid #{key}" do
      expect { build_config(key => value) }.to raise_error(NavOnlineInvoice::ConfigurationError, /#{key}/)
    end
  end

  it "accepts a 16 character exchange key or none" do
    expect(build_config(exchange_key: "spec-exchange-k1").exchange_key).to eq("spec-exchange-k1")
    expect(build_config(exchange_key: nil).exchange_key).to be_nil
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
    config = build_config(exchange_key: "spec-exchange-k1")
    output = config.inspect

    expect(output).not_to include("specuser0000001", "spec-signature-key", "spec-exchange-k1", config.password_hash)
    expect(output).to include("login=[FILTERED]", "tax_number=\"12345678\"")
  end

  it "hides the credentials in pp, IRB and to_h" do
    config = build_config

    expect(config.pretty_inspect).not_to include("spec-signature-key", config.password_hash)
    expect(config.to_h).to include(signature_key: "[FILTERED]", password_hash: "[FILTERED]", tax_number: "12345678")
  end

  it "replaces the password hash when #with gets a new password" do
    config = build_config.with(password: "new-password")

    expect(config.password_hash).to eq(NavOnlineInvoice::Crypto.password_hash("new-password"))
  end

  it "equals a configuration built from the same values" do
    first = build_config

    expect(build_config).to eq(first)
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

    it "turns the throttle off when it is set to nil" do
      builder = described_class.new
      config_attributes(throttle: NavOnlineInvoice::Throttle.default).each do |key, value|
        builder.public_send(:"#{key}=", value)
      end
      builder.throttle = nil

      expect(builder.build.throttle).to be_nil
    end

    it "does not show the assigned values" do
      builder = described_class.new
      builder.password = "spec-password"

      expect([builder.inspect, builder.pretty_inspect].join).not_to include("spec-password")
    end

    it "reports missing values as a configuration error" do
      expect { described_class.new.build }.to raise_error(NavOnlineInvoice::ConfigurationError, /missing/)
    end
  end
end
