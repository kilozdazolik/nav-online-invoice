# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Taxpayer do
  it "does not freeze the caller's address list" do
    addresses = []
    described_class.new(name: "X", taxpayer_id: "12345678", incorporation: :organization, addresses:)

    expect(addresses).not_to be_frozen
  end

  it "leaves the name and the addresses out of inspect and pp" do
    address = NavOnlineInvoice::Address.new(type: :hq, country_code: "HU", postal_code: "9021", city: "BUDAPEST",
                                            street_name: "MINTA", public_place_category: "UTCA", number: "12")
    taxpayer = described_class.new(name: "KOVÁCS BÉLA EV.", taxpayer_id: "12345678", incorporation: :self_employed,
                                   addresses: [address])

    [taxpayer.inspect, PP.pp(taxpayer, +""), address.inspect, taxpayer.to_s].each do |output|
      expect(output).not_to include("KOVÁCS", "MINTA", "9021", "BUDAPEST")
    end
    expect(taxpayer.inspect).to include("12345678", "addresses=1")
  end
end
