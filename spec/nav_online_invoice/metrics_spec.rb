# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Metrics do
  let(:base) { "https://api-test.onlineszamla.nav.gov.hu/metricService/v3/queryServiceMetrics" }
  let(:metrics) { described_class.new(retry_base_delay: 0) }

  def answer(name, status: 200)
    { status:, body: fixture("metrics/#{name}.xml") }
  end

  it "reads all metrics with their values" do
    stub_request(:get, "#{base}/metric").to_return(answer("all"))

    result = metrics.all

    expect(result.updated_at).to eq(Time.utc(2026, 11, 18, 10, 1))
    expect(result.metrics.map(&:name)).to eq(%w[responseTimeAverageMsManageInvoice processingTimeAverageMsInvoice])
    expect(result.metrics.first).to have_attributes(type: :gauge, descriptions: include(:hu, :en, :de))
  end

  it "reads the values as BigDecimal with UTC timestamps, oldest first" do
    stub_request(:get, "#{base}/metric").to_return(answer("all"))

    expect(metrics.all.metrics.first.values.map(&:to_h)).to eq(
      [{ timestamp: Time.utc(2026, 11, 18, 10), value: BigDecimal("412.5") },
       { timestamp: Time.utc(2026, 11, 18, 10, 1), value: BigDecimal("388") }]
    )
  end

  it "reads one metric" do
    stub_request(:get, "#{base}/metric/responseTimeAverageMsManageInvoice").to_return(answer("one"))

    expect(metrics.get("responseTimeAverageMsManageInvoice").values.last.value).to eq(388)
  end

  it "returns nil for a metric NAV does not have" do
    stub_request(:get, "#{base}/metric/noSuchMetric").to_return(status: 404, body: "")

    expect(metrics.get("noSuchMetric")).to be_nil
  end

  it "rejects a name that is not a metric name before sending" do
    expect { metrics.get("../list") }.to raise_error(ArgumentError)
  end

  it "reads the definitions" do
    stub_request(:get, "#{base}/list").to_return(answer("list"))

    expect(metrics.definitions.first).to have_attributes(name: "responseTimeAverageMsManageInvoice", type: :gauge)
    expect(metrics.definitions.first.descriptions[:en]).to start_with("Response times")
  end

  it "raises the NAV error of a failed query" do
    stub_request(:get, "#{base}/metric").to_return(answer("error"))

    expect { metrics.all }.to raise_error(NavOnlineInvoice::TemporaryError, /OPERATION_FAILED/)
  end

  it "retries a timeout, since a GET is safe to repeat" do
    stub_request(:get, "#{base}/metric").to_timeout.then.to_return(answer("all"))

    expect(metrics.all.metrics.size).to eq(2)
  end

  it "raises a TransportError for an answer that is not metrics" do
    stub_request(:get, "#{base}/list").to_return(status: 500, body: "Error")

    expect { metrics.definitions }.to raise_error(NavOnlineInvoice::TransportError)
    expect(a_request(:get, "#{base}/list")).to have_been_made.times(3)
  end

  it "uses the production endpoint and the client's settings" do
    stub_request(:get, "https://api.onlineszamla.nav.gov.hu/metricService/v3/queryServiceMetrics/list")
      .to_return(answer("list"))
    client = NavOnlineInvoice::Client.new(build_config(environment: :production))

    expect(client.metrics.definitions.size).to eq(2)
  end

  it "rejects an unknown environment and bad retry settings" do
    expect { described_class.new(environment: :staging) }.to raise_error(ArgumentError, /environment/)
    expect { described_class.new(max_retries: -1) }.to raise_error(ArgumentError, /max_retries/)
    expect { described_class.new(retry_base_delay: "1") }.to raise_error(ArgumentError, /retry_base_delay/)
  end

  describe "fixtures" do
    Dir[File.join(FixtureHelpers::FIXTURE_DIR, "metrics/*.xml")].each do |path|
      it "#{File.basename(path)} matches the metrics schema" do
        expect(File.read(path)).to be_valid_nav_xml(:metrics)
      end
    end
  end
end
