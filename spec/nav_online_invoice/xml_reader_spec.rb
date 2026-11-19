# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::XmlReader do
  let(:reader) { Object.new.extend(described_class) }
  let(:node) do
    Nokogiri::XML(<<~XML).root
      <r xmlns="#{NavOnlineInvoice::NAMESPACES["api"]}">
        <text>EXAMPLE</text><yes>true</yes><one>1</one><no>false</no><count>42</count><amount>1234.50</amount>
        <date>2026-11-17</date><time>2026-11-17T10:00:00.123Z</time><enum>OUTBOUND</enum><bad>x</bad>
      </r>
    XML
  end

  def read(method, element)
    reader.send(method, node, "api:#{element}")
  end

  it "reads typed values" do
    expect([read(:text, "text"), read(:boolean, "yes"), read(:boolean, "one"), read(:boolean, "no")])
      .to eq(["EXAMPLE", true, true, false])
    expect([read(:integer, "count"), read(:decimal, "amount"), read(:symbol, "enum")])
      .to eq([42, BigDecimal("1234.5"), :outbound])
    expect([read(:date, "date"),
            read(:time, "time")]).to eq([Date.new(2026, 11, 17), Time.utc(2026, 11, 17, 10, 0, 0.123r)])
  end

  it "returns nil for missing or unreadable values" do
    %i[text boolean integer decimal date time symbol].each do |method|
      expect(read(method, "missing")).to be_nil
    end
    expect(%i[boolean integer decimal date time].map { |method| read(method, "bad") }).to all(be_nil)
  end

  it "returns BigDecimal amounts" do
    expect(read(:decimal, "amount")).to be_a(BigDecimal)
  end

  it "reads every lexical form of xs:decimal" do
    values = %w[+5 .5 5. -0.25].map do |value|
      reader.send(:decimal, Nokogiri::XML("<r><v>#{value}</v></r>").root, "v")
    end
    expect(values).to eq([BigDecimal(5), BigDecimal("0.5"), BigDecimal(5), BigDecimal("-0.25")])
  end

  it "rejects decimals with an exponent or no digits" do
    values = %w[1e5 . +].map { |value| reader.send(:decimal, Nokogiri::XML("<r><v>#{value}</v></r>").root, "v") }
    expect(values).to all(be_nil)
  end
end
