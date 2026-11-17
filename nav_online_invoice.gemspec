# frozen_string_literal: true

require_relative "lib/nav_online_invoice/version"

Gem::Specification.new do |spec|
  spec.name = "nav_online_invoice"
  spec.version = NavOnlineInvoice::VERSION
  spec.authors = ["Pálfy Zoltán"]
  spec.email = ["58705226+kilozdazolik@users.noreply.github.com"]

  spec.summary = "Ruby client for the Hungarian NAV Online Invoice (Online Számla) API v3.0"
  spec.description = <<~DESC.tr("\n", " ").strip
    A dependency-light Ruby client for the Hungarian Tax Authority's (NAV) Online Invoice API v3.0:
    request signing, XSD validation, rate limiting and typed errors. Works without Rails;
    an optional Railtie is provided for Rails applications.
  DESC
  spec.homepage = "https://github.com/kilozdazolik/nav-online-invoice"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "schemas/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri", ">= 1.16"
end
