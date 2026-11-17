# frozen_string_literal: true

# Checks an installed nav_online_invoice gem on a machine without a compiler, e.g. a Windows build server:
#
#   gem install --local nav_online_invoice-X.Y.Z.gem
#   ruby windows_smoke.rb
#
# It makes no network calls and needs no credentials.

require "nav_online_invoice"

failures = []
check = lambda do |description, &block|
  raise "returned false" unless block.call

  puts "ok   #{description}"
rescue StandardError, ScriptError => e
  puts "FAIL #{description}: #{e.class}: #{e.message}"
  failures << description
end

puts "Ruby #{RUBY_VERSION} #{RUBY_PLATFORM}, nav_online_invoice #{NavOnlineInvoice::VERSION}"
puts "nokogiri #{Nokogiri::VERSION}, bigdecimal #{Gem.loaded_specs["bigdecimal"]&.version || BigDecimal::VERSION}, " \
     "#{OpenSSL::OPENSSL_LIBRARY_VERSION}"

check.call("SHA3-512 signature matches NAV's official example") do
  NavOnlineInvoice::Crypto.request_signature(
    "RID215118906689", Time.utc(2019, 9, 11, 11, 11, 8), "ac-ac3a-7f661bff7d342N43CYX4U9FG"
  ).start_with?("C5ADE8A2231C509D")
end

config = NavOnlineInvoice::Configuration.new(
  environment: :test, login: "smoketest000001", password: "smoke", signature_key: "smoke-key",
  tax_number: "12345678",
  software: { id: "HU12345678SMOKE-01", name: "Smoke test", operation: :local_software, main_version: "1.0",
              dev_name: "Smoke test", dev_contact: "dev@example.com" }
)

check.call("NAV schemas load and a built request is valid") do
  operation = NavOnlineInvoice::Operations::QueryTaxpayer.new("12345678")
  xml = NavOnlineInvoice::RequestBuilder.new(config).build(operation, request_id: "SMOKE1", time: Time.now)
  NavOnlineInvoice::SchemaValidator.errors(xml).empty?
end

check.call("invoice data schema loads") { NavOnlineInvoice::SchemaValidator.errors("<x/>", schema: :data).any? }
check.call("BigDecimal amounts") { NavOnlineInvoice::Params.amount(:amount, BigDecimal("1234.5")) == "1234.50" }
check.call("gzip decoding") do
  NavOnlineInvoice::Payload.decode([Zlib.gzip("<InvoiceData/>")].pack("m0"), compressed: true) == "<InvoiceData/>"
end

abort "#{failures.size} check(s) failed." unless failures.empty?
puts "All checks passed."
