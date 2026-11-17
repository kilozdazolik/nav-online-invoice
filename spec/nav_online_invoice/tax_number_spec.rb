# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::TaxNumber do
  describe ".normalize" do
    it "keeps an 8-digit tax number" do
      expect(described_class.normalize("12345678")).to eq("12345678")
    end

    it "takes the first 8 digits of the full tax number" do
      expect([described_class.normalize("12345678242"), described_class.normalize("12345678-2-42")])
        .to all(eq("12345678"))
    end

    it "accepts an integer" do
      expect(described_class.normalize(12_345_678)).to eq("12345678")
    end

    it "rejects other values" do
      %w[1234567 123456789 1234567A].each do |value|
        expect { described_class.normalize(value) }.to raise_error(ArgumentError, /Invalid tax number/)
      end
    end
  end
end
