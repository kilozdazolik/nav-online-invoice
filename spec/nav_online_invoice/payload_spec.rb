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

  it "stops unpacking data that would be larger than 20 MB" do
    bomb = [Zlib.gzip("\0" * 20_000_001)].pack("m0")

    expect { described_class.decode(bomb, compressed: true) }.to raise_error(NavOnlineInvoice::DecodeError, /20000000/)
  end

  describe ".encode" do
    it "encodes to strict base64 without line breaks" do
      encoded = described_class.encode(xml * 20, compressed: false)

      expect(encoded).not_to include("\n")
      expect(encoded).to be_frozen
      expect(encoded.unpack1("m0").force_encoding(Encoding::UTF_8)).to eq(xml * 20)
    end

    it "round-trips through decode, compressed or not" do
      [true, false].each do |compressed|
        expect(described_class.decode(described_class.encode(xml, compressed:), compressed:)).to eq(xml)
      end
    end

    it "compresses with gzip" do
      expect(described_class.encode(xml, compressed: true).unpack1("m0").byteslice(0, 2).bytes).to eq([0x1f, 0x8b])
    end
  end
end
