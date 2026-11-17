# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::TransportError do
  it "is retryable by default" do
    expect(described_class.new("timeout")).to be_retryable
  end

  it "can be marked as not retryable" do
    error = described_class.new("not found", http_status: 404, retryable: false)

    expect([error.retryable?, error.http_status]).to eq([false, 404])
  end
end
