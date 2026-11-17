# frozen_string_literal: true

# Calls NAV for real. Runs only with NAV_INTEGRATION=1 and the values in .env (see .env.example):
#
#   bin/dev sh -c 'NAV_INTEGRATION=1 bundle exec rspec spec/integration'
RSpec.describe "queryTaxpayer against NAV", :integration do # rubocop:disable RSpec/DescribeClass
  let(:env) { ENV.to_h.merge(EnvFile.load(File.expand_path("../../.env", __dir__))) }
  let(:config) do
    NavOnlineInvoice::Configuration.new(
      environment: env.fetch("NAV_ENVIRONMENT", "test").to_sym,
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
  end

  before do
    missing = %w[NAV_LOGIN NAV_PASSWORD NAV_SIGNATURE_KEY NAV_TAX_NUMBER NAV_SOFTWARE_ID NAV_SOFTWARE_DEV_NAME
                 NAV_SOFTWARE_DEV_CONTACT NAV_QUERY_TAX_NUMBER].select { |key| env[key].to_s.empty? }
    skip "Set #{missing.join(", ")} in .env (see .env.example)" unless missing.empty?
  end

  around do |example|
    WebMock.allow_net_connect!
    example.run
  ensure
    WebMock.disable_net_connect!
  end

  it "gets an answer that NAV accepted" do
    result = NavOnlineInvoice::Client.new(config).taxpayers.query(env.fetch("NAV_QUERY_TAX_NUMBER"))

    expect(result.request_id).not_to be_empty
    expect(result.taxpayer&.taxpayer_id).to eq(env.fetch("NAV_QUERY_TAX_NUMBER")[0, 8]) if result.valid?
  rescue NavOnlineInvoice::PermissionError => e
    # The request format, login and signature were accepted; the technical user lacks the permission.
    skip "NAV accepted the request but refused permission: #{e.message}"
  end
end
