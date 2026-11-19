# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Address do
  it "holds a simple address without the street parts" do
    address = described_class.new(country_code: "HU", postal_code: "9021", city: "GYŐR",
                                  additional_address_detail: "MINTA UTCA 12.")

    expect(address).to be_simple
    expect([address.type, address.street_name, address.public_place_category]).to all(be_nil)
  end

  it "is detailed without an additional address detail" do
    address = described_class.new(type: :hq, country_code: "HU", postal_code: "9021", city: "GYŐR",
                                  street_name: "MINTA", public_place_category: "UTCA")

    expect(address).not_to be_simple
  end

  it "leaves the address line out of inspect and pp" do
    address = described_class.new(country_code: "HU", postal_code: "9021", city: "GYŐR",
                                  additional_address_detail: "MINTA UTCA 12.")

    [address.inspect, PP.pp(address, +"")].each { |output| expect(output).not_to include("MINTA", "GYŐR", "9021") }
  end
end
