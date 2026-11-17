# frozen_string_literal: true

require "logger"
require "stringio"

RSpec.describe NavOnlineInvoice::Client do
  let(:endpoint) { "https://api-test.onlineszamla.nav.gov.hu/invoiceService/v3/queryTaxpayer" }
  let(:request_ids) { (1..10).map { |n| "RID#{n}" }.each }
  let(:throttle) { instance_spy(NavOnlineInvoice::Throttle) }
  let(:log) { StringIO.new }
  let(:config) do
    build_config(request_id_generator: -> { request_ids.next }, throttle:, retry_base_delay: 0,
                 logger: Logger.new(log, level: :debug))
  end
  let(:client) { described_class.new(config) }

  def nav_answer(path, status: 200)
    { status:, body: fixture("responses/#{path}") }
  end

  it "looks up a taxpayer" do
    stub_request(:post, endpoint).to_return(nav_answer("query_taxpayer/valid.xml"))

    result = client.taxpayers.query("12345678-2-42")

    expect(result).to have_attributes(valid?: true, request_id: "RID1")
    expect(result.taxpayer.name).to start_with("EXAMPLE TRADING")
    expect(a_request(:post, endpoint).with { |request| request.body.include?("<taxNumber>12345678</taxNumber>") })
      .to have_been_made.once
  end

  it "sends a request that matches the NAV schema" do
    stub_request(:post, endpoint).to_return(nav_answer("query_taxpayer/valid.xml"))

    client.taxpayers.query("12345678")

    expect(a_request(:post, endpoint).with { |request| NavOnlineInvoice::SchemaValidator.errors(request.body).empty? })
      .to have_been_made
  end

  it "retries a temporary failure with a new request ID" do
    sent_ids = []
    answers = [nav_answer("general_error/operation_failed.xml", status: 500), nav_answer("query_taxpayer/valid.xml")]
    stub_request(:post, endpoint).to_return do |request|
      sent_ids << request.body[/<common:requestId>(\w+)</, 1]
      answers.shift
    end

    result = client.taxpayers.query("12345678")

    expect(result.request_id).to eq("RID2")
    expect(sent_ids).to eq(%w[RID1 RID2])
    expect(throttle).to have_received(:wait).with("queryTaxpayer").twice
  end

  it "retries a timeout" do
    stub_request(:post, endpoint).to_timeout.then.to_return(nav_answer("query_taxpayer/valid.xml"))

    expect(client.taxpayers.query("12345678")).to be_valid
  end

  it "stops after max_retries" do
    stub_request(:post, endpoint).to_return(nav_answer("general_error/operation_failed.xml", status: 500))

    expect { client.taxpayers.query("12345678") }.to raise_error(NavOnlineInvoice::TemporaryError)
    expect(a_request(:post, endpoint)).to have_been_made.times(3)
  end

  {
    "general_error/forbidden.xml" => [500, NavOnlineInvoice::PermissionError],
    "general_error/invalid_security_user.xml" => [401, NavOnlineInvoice::AuthenticationError],
    "general_error/maintenance_mode.xml" => [503, NavOnlineInvoice::MaintenanceError]
  }.each do |path, (status, klass)|
    it "does not retry #{klass.name.split("::").last}" do
      stub_request(:post, endpoint).to_return(nav_answer(path, status:))

      expect { client.taxpayers.query("12345678") }
        .to raise_error(klass) { |error| expect(error.request_id).to eq("RID1") }
      expect(a_request(:post, endpoint)).to have_been_made.once
    end
  end

  it "does not send a request that fails the schema check" do
    config = build_config(software: ConfigHelpers::SOFTWARE.merge(name: "x" * 51))

    expect { described_class.new(config).taxpayers.query("12345678") }
      .to raise_error(NavOnlineInvoice::SchemaValidationError, /softwareName/)
    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it "logs one line per request without any content" do
    stub_request(:post, endpoint).to_return(nav_answer("query_taxpayer/valid.xml"))

    client.taxpayers.query("12345678")

    expect(log.string).to include("queryTaxpayer request_id=RID1 attempt=1 status=200")
    expect(log.string).not_to include("<", "EXAMPLE TRADING", "12345678")
  end

  it "logs the XML only with log_payloads, and without credentials" do
    stub_request(:post, endpoint).to_return(nav_answer("query_taxpayer/valid.xml"))
    payload_client = described_class.new(config.with(log_payloads: true))

    payload_client.taxpayers.query("12345678")

    expect(log.string).to include("queryTaxpayer request: <?xml", "queryTaxpayer response: <?xml")
    expect(log.string).not_to include(config.password_hash, "specuser0000001")
  end
end
