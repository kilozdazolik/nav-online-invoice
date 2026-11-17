# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Taxpayer do
  it "does not freeze the caller's address list" do
    addresses = []
    described_class.new(name: "X", taxpayer_id: "12345678", incorporation: :organization, addresses:)

    expect(addresses).not_to be_frozen
  end
end
