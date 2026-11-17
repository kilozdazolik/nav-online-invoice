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
      throttle: nil
    }.merge(overrides)
  end

  def build_config(**overrides)
    NavOnlineInvoice::Configuration.new(**config_attributes(**overrides))
  end
end

RSpec.configure do |config|
  config.include ConfigHelpers
end
