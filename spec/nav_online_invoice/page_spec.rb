# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Page do
  def page(current, total, items = [])
    described_class.new(request_id: "RID1", current_page: current, total_pages: total, items:, raw_xml: "<x/>")
  end

  it "knows whether it is the last page" do
    expect([page(1, 2).last_page?, page(2, 2).last_page?, page(1, 0).last_page?]).to eq([false, true, true])
  end

  it "keeps Data#to_h" do
    expect(page(1, 1, [1]).to_h).to include(current_page: 1, items: [1])
  end

  it "shows only the item count in inspect and pp" do
    shown = page(1, 1, ["MINTA JÁNOS"])

    expect([shown.inspect, shown.pretty_inspect].join).not_to include("MINTA", "<x/>")
  end
end
