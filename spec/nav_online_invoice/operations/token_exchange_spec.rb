# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Operations::TokenExchange do
  let(:operation) { described_class.new("spec-exchange-k1") }

  def parse
    xml = fixture("responses/token_exchange/ok.xml")
    operation.parse(Nokogiri::XML(xml), request_id: "RID1", raw_xml: xml)
  end

  it "reproduces NAV's official sample request exactly" do
    xml = NavOnlineInvoice::RequestBuilder.new(official_sample_config)
                                          .build(operation, request_id: "RID896801578348",
                                                            time: Time.utc(2019, 9, 11, 10, 55, 31.44r))

    expect(canonical(xml)).to eq(canonical(fixture("requests/token_exchange_official.xml")))
  end

  it "builds a request that matches the schema" do
    expect(build_request(operation)).to be_valid_nav_xml
  end

  it "decrypts the token and reads its validity" do
    allow(NavOnlineInvoice::ExchangeToken).to receive(:now).and_return(100.0)

    expect(parse).to have_attributes(
      value: "SPEC-TOKEN-0123456789-ABCDEF", received_at: 100.0,
      valid_from: Time.utc(2026, 11, 17, 10), valid_to: Time.utc(2026, 11, 17, 10, 5)
    )
  end

  it "fails when the token does not decrypt with the exchange key" do
    xml = fixture("responses/token_exchange/ok.xml")

    expect { described_class.new("another-key-0000").parse(Nokogiri::XML(xml), request_id: "RID1", raw_xml: xml) }
      .to raise_error(NavOnlineInvoice::DecodeError)
  end

  it "is rate limited and may be retried, since it changes no data" do
    expect(operation).to have_attributes(rate_limited?: true, auto_retry?: true)
  end

  it "does not show the exchange key" do
    expect(operation.inspect).not_to include("spec-exchange-k1")
  end
end
