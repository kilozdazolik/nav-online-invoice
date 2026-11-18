# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::AnnulmentItems do
  let(:time) { Time.utc(2026, 11, 18, 9, 30, 15.25r) }
  let(:item) { { reference: "INV-2026-0001", code: :erratic_data, reason: "Sent with a wrong customer" } }

  def prepare(items)
    described_class.prepare(items, time:, validate: true)
  end

  def decoded(item)
    NavOnlineInvoice::Payload.decode(item.data, compressed: false)
  end

  it "builds an annulment that matches the schema" do
    annulment = prepare([item]).first

    expect(annulment.operation).to eq("ANNUL")
    expect(decoded(annulment)).to be_valid_nav_xml(:annulment)
  end

  it "builds the same annulment as NAV's official sample" do
    sample = Nokogiri::XML(fixture("requests/manage_annulment_official.xml"))
                     .at_xpath("//api:invoiceAnnulment", NavOnlineInvoice::NAMESPACES).text
    item = { reference: "22222222", code: :erratic_data, reason: "create szamla annul",
             timestamp: Time.utc(2018, 6, 18, 9, 10, 45.309r) }

    expect(canonical(decoded(prepare([item]).first))).to eq(canonical(sample.unpack1("m0")))
  end

  it "uses the given time unless an item has its own timestamp, in UTC with milliseconds" do
    own = prepare([item.merge(timestamp: Time.new(2026, 11, 1, 10, 0, 0, "+01:00"))]).first

    expect(decoded(prepare([item]).first)).to include("<annulmentTimestamp>2026-11-18T09:30:15.250Z<")
    expect(decoded(own)).to include("<annulmentTimestamp>2026-11-01T09:00:00.000Z<")
  end

  [
    [{ code: :wrong }, /:code/],
    [{ reference: "" }, /:reference/],
    [{ reference: "x" * 51 }, /:reference/],
    [{ reason: "x" * 1025 }, /:reason/],
    [{ timestamp: Date.new(2026, 1, 1) }, /:timestamp/],
    [{ invoice_number: "X" }, /unknown keys/]
  ].each do |change, message|
    it "rejects #{change.inspect[0, 40]}" do
      expect { prepare([item.merge(change)]) }.to raise_error(ArgumentError, message)
    end
  end

  it "takes 1 to 100 annulments" do
    expect { prepare([]) }.to raise_error(ArgumentError, /1-100/)
    expect { prepare([item] * 101) }.to raise_error(ArgumentError, /1-100/)
  end
end
