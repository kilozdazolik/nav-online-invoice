# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::SubmissionItems do
  let(:invoice_xml) { fixture("invoices/invoice_data.xml") }
  let(:complete_xml) do
    invoice_xml.sub("<completenessIndicator>false</completenessIndicator>",
                    "<completenessIndicator>true</completenessIndicator>")
  end
  let(:sha256) { { value: "ab" * 32, crypto_type: "SHA-256" } }

  def prepare(items, compress: :auto, validate: true)
    described_class.prepare(items, compress:, validate:)
  end

  it "encodes each invoice with its operation, in order" do
    items, compressed = prepare([{ operation: :create, xml: invoice_xml }, { operation: "storno", xml: invoice_xml }])

    expect(compressed).to be(false)
    expect(items.map(&:operation)).to eq(%w[CREATE STORNO])
    expect(NavOnlineInvoice::Payload.decode(items.first.data, compressed: false)).to eq(invoice_xml)
  end

  [
    [[], /1-100/],
    [[{ operation: :create, xml: "<x/>" }] * 101, /1-100/],
    [{ operation: :create, xml: "<x/>" }, /Array/],
    [[{ operation: :create, xml: "<x/>", index: 1 }], /unknown keys/],
    [[{ operation: :annul, xml: "<x/>" }], /items\[1\]\[:operation\]/],
    [[{ operation: :create, xml: "\xFF".b }], /UTF-8/],
    [[{ operation: :create }], /:xml/]
  ].each do |items, message|
    it "rejects #{items.inspect[0, 60]}" do
      expect { prepare(items, validate: false) }.to raise_error(ArgumentError, message)
    end
  end

  it "checks each invoice against the invoiceData schema" do
    expect { prepare([{ operation: :create, xml: "<InvoiceData/>" }]) }
      .to raise_error(NavOnlineInvoice::SchemaValidationError)
  end

  it "rejects an invoice over 15 MB" do
    expect { prepare([{ operation: :create, xml: "x" * 15_000_001 }], validate: false) }
      .to raise_error(NavOnlineInvoice::SubmissionTooLargeError, /15000000/)
  end

  it "compresses automatically only when the request would exceed 10 MB" do
    big = "<x>#{"a" * 7_600_000}</x>"

    expect(prepare([{ operation: :create, xml: big }], validate: false).last).to be(true)
    expect(prepare([{ operation: :create, xml: invoice_xml }]).last).to be(false)
    expect(prepare([{ operation: :create, xml: invoice_xml }], compress: true).last).to be(true)
  end

  it "rejects an unknown compress value" do
    expect { prepare([{ operation: :create, xml: invoice_xml }], compress: :yes) }.to raise_error(ArgumentError)
  end

  it "passes the hash of your own electronic invoice through" do
    items, = prepare([{ operation: :create, xml: invoice_xml, electronic_invoice_hash: sha256 }])

    expect(items.first.electronic_invoice_hash).to eq(value: "AB" * 32, crypto_type: "SHA-256")
  end

  it "rejects a malformed hash" do
    expect { prepare([{ operation: :create, xml: invoice_xml, electronic_invoice_hash: { value: "AB" } }]) }
      .to raise_error(ArgumentError, /electronic_invoice_hash/)
  end

  describe "an invoice that is the electronic invoice itself (completenessIndicator)" do
    it "gets the SHA3-512 of its data as sent" do
      items, = prepare([{ operation: :create, xml: complete_xml }])

      expect(items.first.electronic_invoice_hash)
        .to eq(value: NavOnlineInvoice::Crypto.electronic_invoice_hash(items.first.data), crypto_type: "SHA3-512")
    end

    it "is never compressed" do
      expect(prepare([{ operation: :create, xml: complete_xml }]).last).to be(false)
      expect { prepare([{ operation: :create, xml: complete_xml }], compress: true) }
        .to raise_error(ArgumentError, /cannot be compressed/)
    end

    it "rejects a SHA-256 hash or one that does not match" do
      expect { prepare([{ operation: :create, xml: complete_xml, electronic_invoice_hash: sha256 }]) }
        .to raise_error(ArgumentError, /SHA3-512/)
      expect do
        prepare([{ operation: :create, xml: complete_xml,
                   electronic_invoice_hash: { value: "AB" * 64, crypto_type: "SHA3-512" } }])
      end.to raise_error(ArgumentError, /does not match/)
    end
  end
end
