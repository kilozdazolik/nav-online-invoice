# frozen_string_literal: true

# Downloads NAV's XML schemas from pinned commits into schemas/ and adds the schemaLocation
# attributes that NAV's xs:import elements leave out (libxml2 cannot resolve them otherwise).
namespace :schemas do
  sources = {
    "nav-gov-hu/Online-Invoice@2ef626c71659a2571b1a971822b639a8466aa07e" => {
      "src/schemas/nav/gov/hu/OSA/invoiceApi.xsd" => "invoiceApi.xsd",
      "src/schemas/nav/gov/hu/OSA/invoiceBase.xsd" => "invoiceBase.xsd",
      "src/schemas/nav/gov/hu/OSA/invoiceData.xsd" => "invoiceData.xsd",
      "src/schemas/nav/gov/hu/OSA/invoiceAnnulment.xsd" => "invoiceAnnulment.xsd",
      "src/schemas/nav/gov/hu/OSA/serviceMetrics.xsd" => "serviceMetrics.xsd",
      "LICENCE.md" => "LICENCE.md"
    },
    # Tag common-1.0.0. Common-1.0.RC3 (named in NAV's catalog.xml) lacks the paging types the API
    # schema uses; Common 2.x uses a different namespace.
    "nav-gov-hu/Common@ab8d7887967492e5f6d6e25447be853fd767add8" => {
      "schemas/src/main/resources/xsd/hu/gov/nav/schemas/NTCA/1.0/common/common.xsd" => "common.xsd"
    }
  }

  locations = {
    "http://schemas.nav.gov.hu/NTCA/1.0/common" => "common.xsd",
    "http://schemas.nav.gov.hu/OSA/3.0/base" => "invoiceBase.xsd"
  }

  add_schema_locations = lambda do |content, target|
    patched = content.gsub(%r{<xs:import\s+namespace="([^"]+)"\s*/>}) do
      namespace = Regexp.last_match(1)
      location = locations.fetch(namespace) { abort "#{target}: no local schema for import #{namespace}" }
      %(<xs:import namespace="#{namespace}" schemaLocation="#{location}"/>)
    end
    abort "#{target}: an xs:import has no schemaLocation" if patched.match?(/<xs:import(?![^>]*schemaLocation)/)
    patched
  end

  desc "Download NAV's XSD schemas into schemas/ and add the missing schemaLocation attributes"
  task :sync do
    require "net/http"
    require "digest"

    dir = File.expand_path("../schemas", __dir__)
    sources.each do |source, files|
      repo, sha = source.split("@")
      files.each do |path, target|
        uri = URI("https://raw.githubusercontent.com/#{repo}/#{sha}/#{path}")
        response = Net::HTTP.get_response(uri)
        abort "Download failed (HTTP #{response.code}): #{uri}" unless response.is_a?(Net::HTTPSuccess)

        content = response.body.force_encoding(Encoding::UTF_8)
        content = add_schema_locations.call(content, target) if target.end_with?(".xsd")

        File.binwrite(File.join(dir, target), content)
        puts "#{Digest::SHA256.hexdigest(content)}  #{target}"
      end
    end
  end
end
