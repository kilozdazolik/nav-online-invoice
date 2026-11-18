# frozen_string_literal: true

module ConfigHelpers
  # Invented values; never real credentials.
  SOFTWARE = {
    id: "HU12345678TEST-001",
    name: "Spec Suite",
    operation: :local_software,
    main_version: "1.0",
    dev_name: "Example Developer",
    dev_contact: "dev@example.com"
  }.freeze

  def config_attributes(**overrides)
    {
      environment: :test,
      login: "specuser0000001",
      password: "spec-password",
      signature_key: "spec-signature-key-0000000000000",
      tax_number: "12345678",
      software: SOFTWARE,
      exchange_key: "spec-exchange-k1",
      throttle: nil
    }.merge(overrides)
  end

  # The values of NAV's official sample requests.
  def official_sample_config
    NavOnlineInvoice::Configuration.new(
      environment: :test,
      login: "lwilsmn0uqdxe6u",
      password_hash: "2F43840A882CFDB7DB0FEC07D419D030D864B47B6B541DC280EF81B937B7A176" \
                     "E33C052B0D26638CC18A7A2C08D8D311733078A774BF43F6CA57FE8CD74DC28E",
      signature_key: "ac-ac3a-7f661bff7d342N43CYX4U9FG",
      tax_number: "11111111",
      software: {
        id: "123456789123456789", name: "string", operation: :local_software, main_version: "string",
        dev_name: "string", dev_contact: "string", dev_country_code: "HU", dev_tax_number: "string"
      }
    )
  end

  def build_config(**overrides)
    NavOnlineInvoice::Configuration.new(**config_attributes(**overrides))
  end
end

RSpec.configure do |config|
  config.include ConfigHelpers
end
