# frozen_string_literal: true

# Settings for the specs that call NAV for real (spec/integration). Only these specs read ENV and .env.
RSpec.shared_context "with NAV credentials" do
  let(:env) { ENV.to_h.merge(EnvFile.load(File.expand_path("../../.env", __dir__))) }
  let(:environment) { env.fetch("NAV_ENVIRONMENT", "test").to_sym }
  let(:client) do
    NavOnlineInvoice::Client.new(
      NavOnlineInvoice::Configuration.new(
        environment: environment,
        login: env.fetch("NAV_LOGIN"),
        password: env.fetch("NAV_PASSWORD"),
        signature_key: env.fetch("NAV_SIGNATURE_KEY"),
        tax_number: env.fetch("NAV_TAX_NUMBER"),
        software: {
          id: env.fetch("NAV_SOFTWARE_ID"),
          name: "nav_online_invoice",
          operation: :local_software,
          main_version: NavOnlineInvoice::VERSION,
          dev_name: env.fetch("NAV_SOFTWARE_DEV_NAME"),
          dev_contact: env.fetch("NAV_SOFTWARE_DEV_CONTACT")
        }
      )
    )
  end

  before do
    missing = %w[NAV_LOGIN NAV_PASSWORD NAV_SIGNATURE_KEY NAV_TAX_NUMBER NAV_SOFTWARE_ID NAV_SOFTWARE_DEV_NAME
                 NAV_SOFTWARE_DEV_CONTACT].select { |key| env[key].to_s.empty? }
    skip "Set #{missing.join(", ")} in .env (see .env.example)" unless missing.empty?
  end

  around do |example|
    WebMock.allow_net_connect!
    example.run
  ensure
    WebMock.disable_net_connect!
  end

  # Runs NAV calls; a refused permission skips the example, since NAV accepted the format, login and signature.
  def nav
    yield
  rescue NavOnlineInvoice::PermissionError => e
    skip "NAV accepted the request but refused permission: #{e.message}"
  end
end
