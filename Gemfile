# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# The version bundled with Ruby 4.0, so CI on Windows uses it instead of compiling a newer one.
gem "bigdecimal", "4.1.3"

gem "logger"
gem "rake", "~> 13.0"
gem "rspec", "~> 3.13"
gem "rubocop", "~> 1.70", require: false
gem "rubocop-rake", require: false
gem "rubocop-rspec", require: false
gem "webmock", "~> 3.23"

# API documentation (`bundle exec yard`); pure Ruby, so Windows needs no compiler.
gem "kramdown", require: false
gem "kramdown-parser-gfm", require: false
gem "yard", require: false
