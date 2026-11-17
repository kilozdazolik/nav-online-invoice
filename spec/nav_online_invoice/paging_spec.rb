# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Paging do
  let(:fetched) { [] }
  let(:items) do
    described_class.items(nil) do |number|
      fetched << number
      NavOnlineInvoice::Page.new(request_id: "R#{number}", current_page: number, total_pages: 3,
                                 items: ["#{number}a", "#{number}b"], raw_xml: "")
    end
  end

  it "walks all pages" do
    expect(items.to_a).to eq(%w[1a 1b 2a 2b 3a 3b])
  end

  it "fetches only the pages that are read" do
    items.first(3)

    expect(fetched).to eq([1, 2])
  end

  it "stops after max_pages" do
    limited = described_class.items(2) do |number|
      NavOnlineInvoice::Page.new(request_id: "R", current_page: number, total_pages: 9, items: [number], raw_xml: "")
    end

    expect(limited.to_a).to eq([1, 2])
  end
end
