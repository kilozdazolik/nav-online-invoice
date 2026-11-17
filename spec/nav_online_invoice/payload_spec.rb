# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Payload do
  let(:xml) { "<InvoiceData>Számla</InvoiceData>" }

  it "decodes base64, with line breaks allowed" do
    encoded = [xml].pack("m") # 60-character lines

    expect(described_class.decode(encoded, compressed: false)).to eq(xml)
  end

  it "decodes gzip-compressed data" do
    expect(described_class.decode([Zlib.gzip(xml)].pack("m0"), compressed: true)).to eq(xml)
  end

  it "raises DecodeError on broken data" do
    ["not base64!", [xml].pack("m0")].each do |broken|
      expect { described_class.decode(broken, compressed: true) }.to raise_error(NavOnlineInvoice::DecodeError)
    end
    expect { described_class.decode(["\xFF\xFE".b].pack("m0"), compressed: false) }
      .to raise_error(NavOnlineInvoice::DecodeError, /UTF-8/)
  end
end
