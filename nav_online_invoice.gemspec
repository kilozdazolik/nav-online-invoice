# frozen_string_literal: true

require_relative "lib/nav_online_invoice/version"

Gem::Specification.new do |spec|
  spec.name = "nav_online_invoice"
  spec.version = NavOnlineInvoice::VERSION
  spec.authors = ["Pálfy Zoltán"]
  spec.email = ["58705226+kilozdazolik@users.noreply.github.com"]

  spec.summary = "Ruby client for the Hungarian NAV Online Invoice (Online Számla) API v3.0"
  spec.description = <<~DESC.tr("\n", " ").strip
    A dependency-light client for the Hungarian Tax Authority's (NAV) Online Invoice API v3.0, with
    request signing, schema validation, rate limiting and typed errors. Works with or without Rails.
  DESC
  spec.homepage = "https://github.com/kilozdazolik/nav-online-invoice"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/v#{spec.version}/CHANGELOG.md",
    "documentation_uri" => "https://www.rubydoc.info/gems/nav_online_invoice/#{spec.version}",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "lib/**/*.tt", "schemas/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  # Any version Ruby ships with is enough; a newer one would have to be compiled on Windows.
  spec.add_dependency "bigdecimal", ">= 3.1"
  # 1.19.5 fixes the latest libxml2 advisories (GHSA-3w22-6jfg-527w and others).
  spec.add_dependency "nokogiri", ">= 1.19.5", "< 2"
end
