# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::RequestId do
  it "matches NAV's request ID format" do
    expect(described_class.call).to match(/\A[+a-zA-Z0-9_]{1,30}\z/)
  end

  it "generates unique IDs" do
    ids = Array.new(1000) { described_class.call }

    expect(ids.uniq.size).to eq(1000)
  end

  it "uses the given prefix" do
    expect(described_class.call(prefix: "ACME")).to start_with("ACME")
  end
end
