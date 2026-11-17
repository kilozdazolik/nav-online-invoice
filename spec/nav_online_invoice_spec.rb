# frozen_string_literal: true

RSpec.describe NavOnlineInvoice do
  it "has a semantic version number" do
    expect(NavOnlineInvoice::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "defines a base error class" do
    expect(NavOnlineInvoice::Error.ancestors).to include(StandardError)
  end
end
