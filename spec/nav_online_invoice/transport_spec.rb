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

  it "marks a failure while connecting as not sent" do
    http = Net::HTTP.new(uri.host, uri.port)
    allow(http).to receive(:start).and_raise(Net::OpenTimeout)
    allow(Net::HTTP).to receive(:new).and_return(http)

    expect { transport.post(uri, "<request/>") }
      .to raise_error(NavOnlineInvoice::TransportError) { |error| expect(error).not_to be_request_sent }
  end

  it "marks a failure after connecting as possibly sent" do
    stub_request(:post, uri).to_raise(Net::ReadTimeout)

    expect { transport.post(uri, "<request/>") }
      .to raise_error(NavOnlineInvoice::TransportError, &:request_sent?)
  end

  it "gets a resource without a body" do
    stub_request(:get, uri).with(headers: { "Accept" => "application/xml" }).to_return(status: 200, body: "<ok/>")

    expect(transport.get(uri)).to eq(described_class::Response.new(status: 200, body: "<ok/>"))
    expect(a_request(:get, uri).with { |request| request.body.to_s.empty? }).to have_been_made.once
  end

  it "refuses a URL without https" do
    expect { transport.post(URI("http://api-test.onlineszamla.nav.gov.hu/x"), "<request/>") }
      .to raise_error(ArgumentError, /https/)
  end

  it "verifies the certificate and requires TLS 1.2 or later" do
    http = Net::HTTP.new(uri.host, uri.port)
    allow(Net::HTTP).to receive(:new).and_return(http)
    stub_request(:post, uri).to_return(body: "<ok/>")

    transport.post(uri, "<request/>")

    expect(http).to have_attributes(use_ssl?: true, verify_mode: OpenSSL::SSL::VERIFY_PEER,
                                    min_version: OpenSSL::SSL::TLS1_2_VERSION)
  end
end
