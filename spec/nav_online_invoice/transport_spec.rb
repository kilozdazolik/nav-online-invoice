# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Transport do
  let(:transport) { described_class.new(open_timeout: 5, read_timeout: 60, write_timeout: 60) }
  let(:uri) { URI("https://api-test.onlineszamla.nav.gov.hu/invoiceService/v3/queryTaxpayer") }

  it "posts the XML and returns the status and body" do
    stub_request(:post, uri).to_return(status: 200, body: "<ok/>")

    response = transport.post(uri, "<request/>")

    expect(response).to eq(described_class::Response.new(status: 200, body: "<ok/>"))
    expect(a_request(:post, uri).with(body: "<request/>", headers: {
                                        "Content-Type" => "application/xml; charset=UTF-8",
                                        "Accept" => "application/xml"
                                      })).to have_been_made.once
  end

  it "returns error statuses instead of raising" do
    stub_request(:post, uri).to_return(status: 500, body: "Error")

    expect(transport.post(uri, "<request/>").status).to eq(500)
  end

  it "raises a retryable TransportError on a timeout" do
    stub_request(:post, uri).to_timeout

    expect { transport.post(uri, "<request/>") }.to raise_error(NavOnlineInvoice::TransportError, &:retryable?)
  end

  it "raises a retryable TransportError when the connection is refused" do
    stub_request(:post, uri).to_raise(Errno::ECONNREFUSED)

    expect { transport.post(uri, "<request/>") }.to raise_error(NavOnlineInvoice::TransportError, /ECONNREFUSED/)
  end

  it "does not retry a certificate error" do
    stub_request(:post, uri).to_raise(OpenSSL::SSL::SSLError.new("certificate verify failed"))

    expect { transport.post(uri, "<request/>") }
      .to raise_error(NavOnlineInvoice::TransportError) { |error| expect(error).not_to be_retryable }
  end

  it "wraps errors of a broken response" do
    [Zlib::DataError.new("incorrect header check"), Net::HTTPHeaderSyntaxError.new("wrong Content-Length")]
      .each do |error|
        stub_request(:post, uri).to_raise(error)

        expect { transport.post(uri, "<request/>") }.to raise_error(NavOnlineInvoice::TransportError)
      end
  end

  it "sends the request only once" do
    stub_request(:post, uri).to_raise(EOFError)

    expect { transport.post(uri, "<request/>") }.to raise_error(NavOnlineInvoice::TransportError)
    expect(a_request(:post, uri)).to have_been_made.once
  end
end
