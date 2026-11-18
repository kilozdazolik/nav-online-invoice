# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Params do
  describe ".direction and .enum" do
    it "converts symbols to NAV values" do
      expect([described_class.direction(:outbound), described_class.enum(:x, :transfer, %w[TRANSFER CASH])])
        .to eq(%w[OUTBOUND TRANSFER])
    end

    it "rejects unknown values" do
      expect { described_class.direction(:sideways) }.to raise_error(ArgumentError, /direction must be one of/)
    end
  end

  describe ".date_range" do
    let(:from) { Date.new(2026, 11, 1) }

    it "returns the first and the last day" do
      expect(described_class.date_range(:issue_date, from..(from + 35))).to eq([from, from + 35])
      expect(described_class.date_range(:issue_date, from...(from + 1))).to eq([from, from])
    end

    it "rejects long, reversed and non-date ranges" do
      expect { described_class.date_range(:issue_date, from..(from + 36)) }.to raise_error(ArgumentError, /35 days/)
      expect { described_class.date_range(:issue_date, (from + 1)..from) }.to raise_error(ArgumentError, /after/)
      expect { described_class.date_range(:issue_date, from..) }.to raise_error(ArgumentError, /Range of Dates/)
    end
  end

  describe ".time_range" do
    let(:from) { Time.utc(2026, 11, 1) }

    it "returns both ends in UTC" do
      local = Time.new(2026, 11, 1, 2, 0, 0, "+02:00")

      expect(described_class.time_range(:ins_date, local..(local + 3600))).to eq([from, from + 3600])
    end

    it "rejects exclusive, long and reversed ranges" do
      expect { described_class.time_range(:ins_date, from...(from + 1)) }.to raise_error(ArgumentError, /inclusive/)
      expect { described_class.time_range(:ins_date, from..(from + (841 * 3600))) }
        .to raise_error(ArgumentError, /840 hours/)
      expect { described_class.time_range(:ins_date, (from + 1)..from) }.to raise_error(ArgumentError, /after/)
    end
  end

  describe ".amount" do
    it "formats with two decimals without losing precision" do
      expect([1000, 1234.5, BigDecimal("0.1"), "-12.30", Rational(5, 2), 123_456_789_012_345.67r]
               .map { |value| described_class.amount(:net_amount, value) })
        .to eq(%w[1000.00 1234.50 0.10 -12.30 2.50 123456789012345.67])
    end

    it "rejects more than two decimals and non-numbers" do
      [1.005, Rational(1, 3), "12,5", nil].each do |value|
        expect { described_class.amount(:net_amount, value) }.to raise_error(ArgumentError, /net_amount/)
      end
    end
  end

  describe ".relational" do
    let(:day) { Date.new(2026, 11, 17) }

    it "maps a value to EQ and a range to a closed pair" do
      expect(described_class.relational(:net_amount, 1000, :amount)).to eq([%w[EQ 1000.00]])
      expect(described_class.relational(:net_amount, 1000..5000, :amount)).to eq([%w[GTE 1000.00], %w[LTE 5000.00]])
      expect(described_class.relational(:payment_date, day...(day + 1), :date))
        .to eq([%w[GTE 2026-11-17], %w[LT 2026-11-18]])
    end

    it "rejects open ranges, which NAV does not accept" do
      expect { described_class.relational(:net_amount, 1000.., :amount) }.to raise_error(ArgumentError, /both/)
    end
  end

  it "validates pages and indexes" do
    expect { described_class.page(0) }.to raise_error(ArgumentError, /page/)
    expect { described_class.index(:index, 101) }.to raise_error(ArgumentError, /1 to 100/)
  end

  it "leaves free text and tax numbers out of the error message" do
    expect { described_class.text(:name, "Kovács", min: 7, max: 9) }
      .to raise_error(ArgumentError) { |error| expect(error.message).not_to include("Kovács") }
    expect { described_class.tax_number(:tax_number, "1234567") }
      .to raise_error(ArgumentError) { |error| expect(error.message).not_to include("1234567") }
  end

  it "validates transaction IDs, tax numbers and texts" do
    expect { described_class.transaction_id("bad id") }.to raise_error(ArgumentError, /transaction_id/)
    expect { described_class.tax_number(:tax_number, "123") }.to raise_error(ArgumentError, /tax_number/)
    expect { described_class.text(:name, "ABC", min: 5, max: 512) }.to raise_error(ArgumentError, /5-512/)
  end

  it "formats timestamps in UTC with milliseconds" do
    expect(described_class.timestamp(Time.new(2026, 11, 17, 12, 0, 0.5r, "+01:00"))).to eq("2026-11-17T11:00:00.500Z")
  end
end
