# frozen_string_literal: true

# Calls NAV's service metrics for real. They need no credentials, so this runs without .env:
#
#   bin/dev sh -c 'NAV_INTEGRATION=1 bundle exec rspec spec/integration/service_metrics_spec.rb'
RSpec.describe "Service metrics against NAV", :integration do # rubocop:disable RSpec/DescribeClass
  let(:metrics) { NavOnlineInvoice::Metrics.new(environment: ENV.fetch("NAV_ENVIRONMENT", "test").to_sym) }

  around do |example|
    WebMock.allow_net_connect!
    example.run
  ensure
    WebMock.disable_net_connect!
  end

  it "lists the metric definitions" do
    definitions = metrics.definitions

    expect(definitions).not_to be_empty
    expect(definitions.map(&:type).uniq - %i[counter gauge histogram summary]).to be_empty
  end

  it "reads all metrics and one of them by name" do
    all = metrics.all
    name = all.metrics.first&.name
    skip "NAV returned no metrics" unless name

    expect(metrics.get(name).name).to eq(name)
    expect(metrics.get("noSuchMetricOfTheSpecSuite")).to be_nil
  end
end
