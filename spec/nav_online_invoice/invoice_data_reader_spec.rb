# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::InvoiceDataReader do
  def invoices(name)
    described_class.new(Nokogiri::XML(fixture("invoices/#{name}.xml")), version: "3.0").invoices
  end

  def read(name) = invoices(name).first

  # Every fixture in spec/fixtures/invoices also matches NAV's schema: see schema_validator_spec.rb.
  %w[invoice_data foreign_currency simplified modification storno batch private_person].each do |name|
    it "reads #{name}.xml" do
      expect(invoices(name)).to all(be_a(NavOnlineInvoice::Invoice))
    end
  end

  it "reads the invoice details" do
    expect(read("invoice_data")).to have_attributes(
      invoice_number: "INV-2026-0001", issue_date: Date.new(2026, 11, 16), completeness_indicator: false,
      batch_index: nil, reference: nil, category: :normal, delivery_date: Date.new(2026, 11, 16), currency: "HUF",
      exchange_rate: BigDecimal(1), payment_method: :transfer, payment_date: Date.new(2026, 11, 24),
      appearance: :electronic, small_business: false, cash_accounting: false, fiscal_representative: nil
    )
  end

  it "reads the parties with simple addresses" do
    invoice = read("invoice_data")

    expect(invoice.supplier).to have_attributes(tax_number: "12345678-2-42", name: "EXAMPLE TRADING KFT.",
                                                bank_account_number: nil, vat_status: nil)
    expect(invoice.supplier.address).to have_attributes(city: "BUDAPEST", postal_code: "1234",
                                                        additional_address_detail: "MINTA UTCA 12.")
    expect(invoice.customer).to have_attributes(tax_number: "87654321-1-13", vat_status: :domestic,
                                                name: "PÉLDA ÜGYFÉL BT.")
  end

  it "reads the stated totals" do
    expect(read("invoice_data").summary).to have_attributes(
      simplified: false, net_amount: 20_000, net_amount_huf: 20_000, vat_amount: 5400, vat_amount_huf: 5400,
      gross_amount: 25_400, gross_amount_huf: 25_400, gross_calculated: false
    )
  end

  it "reads a foreign currency invoice with detailed addresses and bank accounts" do
    invoice = read("foreign_currency")

    expect(invoice).to have_attributes(currency: "EUR", exchange_rate: BigDecimal("400.5"))
    expect(invoice.supplier).to have_attributes(group_member_tax_number: "11223344-4-41",
                                                community_vat_number: "HU12345678",
                                                bank_account_number: "HU00123456781234567812345678")
    expect(invoice.supplier.address).to have_attributes(street_name: "MINTA", public_place_category: "UTCA",
                                                        number: "12", floor: "2", additional_address_detail: nil)
    expect(invoice.customer).to have_attributes(vat_status: :other, tax_number: nil,
                                                community_vat_number: "DE123456789",
                                                bank_account_number: "DE00123456781234567890")
  end

  it "reads the totals in both currencies, by VAT rate too" do
    summary = read("foreign_currency").summary

    expect(summary).to have_attributes(gross_amount: 1270, gross_amount_huf: 508_635, gross_calculated: false)
    expect(summary.by_vat_rate.first).to have_attributes(net_amount: 1000, net_amount_huf: 400_500, vat_amount: 270,
                                                         vat_amount_huf: 108_135, gross_amount: 1270,
                                                         gross_amount_huf: 508_635)
    expect(summary.by_vat_rate.first.vat_rate).to eq(NavOnlineInvoice::VatRate.new(kind: :percentage, rate: 0.27r))
  end

  it "adds up the gross total of a simplified invoice that does not give it" do
    summary = read("simplified").summary

    expect(summary).to have_attributes(simplified?: true, gross_calculated?: true, gross_amount: 13_750,
                                       gross_amount_huf: 13_750, net_amount: nil, vat_amount: nil)
    expect(summary.by_vat_rate.map { |rate| [rate.vat_rate.kind, rate.vat_rate.rate, rate.gross_amount] })
      .to eq([[:content, BigDecimal("0.2126"), 12_700], [:content, BigDecimal("0.0476"), 1050]])
  end

  it "adds net and VAT when a normal invoice gives no gross total" do
    expect(read("private_person").summary).to have_attributes(gross_amount: 8000, gross_calculated?: true)
  end

  it "reads a modification, whose amounts are the change" do
    invoice = read("modification")

    expect(invoice).to be_modification
    expect(invoice.reference).to eq(NavOnlineInvoice::InvoiceReference.new(
                                      original_invoice_number: "INV-2026-0001", modify_without_master: false,
                                      modification_timestamp: nil, modification_index: 1
                                    ))
    expect(invoice.customer).to be_nil
    expect(invoice.summary).to have_attributes(net_amount: -5000, gross_amount: -6350)
  end

  it "reads a storno with negative amounts" do
    expect(read("storno")).to have_attributes(modification?: true, reference: have_attributes(modification_index: 2))
    expect(read("storno").summary.gross_amount).to eq(-19_050)
  end

  it "reads each invoice of a batch modification, in batch order" do
    batch = invoices("batch")

    expect(batch.map(&:batch_index)).to eq([1, 2])
    expect(batch.map { |invoice| invoice.reference.original_invoice_number }).to eq(%w[INV-2026-0010 INV-2026-0011])
    expect(batch.map { |invoice| invoice.summary.gross_amount }).to eq([-1270, -2540])
  end

  it "reads a private customer, the exemption and the indicators" do
    invoice = read("private_person")

    expect(invoice.customer).to eq(NavOnlineInvoice::InvoiceParty.new(vat_status: :private_person))
    expect(invoice.summary.by_vat_rate.first.vat_rate)
      .to eq(NavOnlineInvoice::VatRate.new(kind: :exemption, code: "AAM", reason: "Alanyi adómentes"))
    expect(invoice).to have_attributes(small_business: true, cash_accounting: true, payment_method: :card)
  end

  it "reads every form of VAT rate" do
    forms = {
      "<vatOutOfScope><case>ATK</case><reason>Az áfa tárgyi hatályán kívül</reason></vatOutOfScope>" =>
        { kind: :out_of_scope, code: "ATK", reason: "Az áfa tárgyi hatályán kívül" },
      "<vatDomesticReverseCharge>true</vatDomesticReverseCharge>" => { kind: :domestic_reverse_charge },
      "<marginSchemeIndicator>SECOND_HAND</marginSchemeIndicator>" => { kind: :margin_scheme, code: "SECOND_HAND" },
      "<vatAmountMismatch><vatRate>0.27</vatRate><case>REFUNDABLE_VAT</case></vatAmountMismatch>" =>
        { kind: :amount_mismatch, rate: 0.27r, code: "REFUNDABLE_VAT" },
      "<noVatCharge>true</noVatCharge>" => { kind: :no_vat_charge }
    }
    forms.each do |form, expected|
      xml = fixture("invoices/invoice_data.xml").sub(%r{<vatRate>\s*<vatPercentage>0.27</vatPercentage>\s*</vatRate>},
                                                     "<vatRate>#{form}</vatRate>")
      rate = described_class.new(Nokogiri::XML(xml)).invoices.first.summary.by_vat_rate.first.vat_rate
      expect(rate).to eq(NavOnlineInvoice::VatRate.new(**expected))
    end
  end

  it "reads the fiscal representative" do
    representative = <<~XML
      <fiscalRepresentativeInfo>
        <fiscalRepresentativeTaxNumber><base:taxpayerId>99887766</base:taxpayerId></fiscalRepresentativeTaxNumber>
        <fiscalRepresentativeName>KÉPVISELŐ KFT.</fiscalRepresentativeName>
        <fiscalRepresentativeAddress><base:simpleAddress><base:countryCode>HU</base:countryCode>
          <base:postalCode>1111</base:postalCode><base:city>BUDAPEST</base:city>
          <base:additionalAddressDetail>FŐ UTCA 1.</base:additionalAddressDetail></base:simpleAddress>
        </fiscalRepresentativeAddress>
      </fiscalRepresentativeInfo>
    XML
    xml = fixture("invoices/invoice_data.xml").sub("<invoiceDetail>", "#{representative}<invoiceDetail>")

    expect(xml).to be_valid_nav_xml(:data)
    expect(described_class.new(Nokogiri::XML(xml)).invoices.first.fiscal_representative)
      .to have_attributes(tax_number: "99887766", name: "KÉPVISELŐ KFT.", address: have_attributes(city: "BUDAPEST"))
  end

  it "refuses invoices in an older format" do
    xml = '<InvoiceData xmlns="http://schemas.nav.gov.hu/OSA/2.0/data"><invoiceNumber>X</invoiceNumber></InvoiceData>'
    reader = described_class.new(Nokogiri::XML(xml), version: "2.0")

    expect { reader.invoices }.to raise_error(NavOnlineInvoice::UnsupportedInvoiceVersionError, /format 2\.0/)
  end

  it "makes UnsupportedInvoiceVersionError a DecodeError" do
    expect(NavOnlineInvoice::UnsupportedInvoiceVersionError).to be < NavOnlineInvoice::DecodeError
  end
end
