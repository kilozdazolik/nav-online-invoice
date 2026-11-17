# frozen_string_literal: true

# Calls NAV for real. Runs only with NAV_INTEGRATION=1 and the values in .env (see .env.example):
#
#   bin/dev sh -c 'NAV_INTEGRATION=1 bundle exec rspec spec/integration'
RSpec.describe "queryTaxpayer against NAV", :integration do # rubocop:disable RSpec/DescribeClass
  include_context "with NAV credentials"

  before { skip "Set NAV_QUERY_TAX_NUMBER in .env" if env["NAV_QUERY_TAX_NUMBER"].to_s.empty? }

  it "gets an answer that NAV accepted" do
    result = nav { client.taxpayers.query(env.fetch("NAV_QUERY_TAX_NUMBER")) }

    expect(result.request_id).not_to be_empty
    expect(result.matches?(env.fetch("NAV_QUERY_TAX_NUMBER")[0, 8])).to be(true) if result.valid?
  end
end
