# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

# Releases go through the tag workflow (trusted publishing), never from a developer machine.
Rake::Task["release"].clear
desc "Releases are published by GitHub Actions; see README"
task :release do
  abort "Push a version tag instead: git tag -a vX.Y.Z -m \"Version X.Y.Z\" && git push origin vX.Y.Z"
end

namespace :release do
  desc "Fail unless CHANGELOG.md has a section for the current version (and the tag matches, if given)"
  task :check do
    require_relative "lib/nav_online_invoice/version"
    version = NavOnlineInvoice::VERSION

    changelog = File.read(File.expand_path("CHANGELOG.md", __dir__))
    abort "CHANGELOG.md has no section for #{version}" unless changelog.match?(/^## \[#{Regexp.escape(version)}\]/)

    tag = ENV.fetch("RELEASE_TAG", nil)
    abort "Tag #{tag} does not match version v#{version}" if tag && tag != "v#{version}"

    puts "release:check OK (#{version})"
  end
end
