# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Operations::Base do
  let(:operation) { Class.new(described_class) { def name = "queryInvoiceDigest" }.new }

  it "derives the root elements from the name" do
    expect([operation.request_root, operation.response_root])
      .to eq(%w[QueryInvoiceDigestRequest QueryInvoiceDigestResponse])
  end

  it "is rate limited and not retried unless the subclass says otherwise" do
    expect([operation.rate_limited?, operation.auto_retry?]).to eq([true, false])
  end

  it "adds no index hashes to the signature" do
    expect(operation.index_hashes).to eq([])
  end

  it "requires the subclass to define the operation" do
    expect { described_class.new.name }.to raise_error(NotImplementedError)
    expect { operation.build_body(nil) }.to raise_error(NotImplementedError)
  end
end
