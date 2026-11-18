# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::ExchangeToken do
  let(:token) do
    described_class.new(value: "SECRET-TOKEN", valid_from: Time.utc(2026, 11, 17, 10),
                        valid_to: Time.utc(2026, 11, 17, 10, 5), received_at: 1000.0)
  end

  it "is fresh while more than the margin of its validity window is left" do
    expect(token.fresh?(1000.0 + 269)).to be(true)
    expect(token.fresh?(1000.0 + 271)).to be(false)
  end

  it "ignores the local wall clock" do
    allow(Time).to receive(:now).and_return(Time.utc(2030, 1, 1))

    expect(token.fresh?(1001.0)).to be(true)
  end

  it "tells NAV's time from the validity start and the time since it arrived" do
    expect(token.nav_time(1000.0 + 90)).to eq(Time.utc(2026, 11, 17, 10, 1, 30))
  end

  it "is never fresh without a validity window" do
    expect(token.with(valid_to: nil).fresh?(1000.0)).to be(false)
  end

  it "hides the token in inspect and pp" do
    expect(token.inspect).not_to include("SECRET-TOKEN")
    expect(PP.pp(token, +"")).not_to include("SECRET-TOKEN")
  end
end
