# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "fileutils"
require_relative "lib/auditron/version"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

# -----------------------------------------------------------------------------
# publish: clean -> lint -> spec -> build -> push to RubyGems.org
#
# Usage:
#   ruby publish.rb                    # full automated pipeline (any OS)
#   sh publish.sh                      # same pipeline (Mac / Linux / Git Bash)
#   bundle exec rake publish           # lint + spec + build + push
#   bundle exec rake publish:build     # build only
#   bundle exec rake publish:push      # push only (skips lint, spec and build)
# -----------------------------------------------------------------------------

GEM_NAME    = "auditron"
GEM_VERSION = Gem::Version.new(Auditron::VERSION).to_s
GEM_FILE    = "#{GEM_NAME}-#{GEM_VERSION}.gem".freeze
GEMSPEC     = "#{GEM_NAME}.gemspec".freeze

namespace :publish do
  desc "Move built .gem files to the Gems/ folder"
  task :clean do
    FileUtils.mkdir_p("Gems")
    Dir["*.gem"].each do |file|
      FileUtils.mv(file, "Gems/#{file}")
      puts "📦  Moved #{file} → Gems/#{file}"
    end
  end

  desc "Run RuboCop"
  task :lint do
    puts "\n#{"=" * 60}"
    puts "  Running RuboCop for #{GEM_NAME} v#{GEM_VERSION}"
    puts "=" * 60
    sh "bundle exec rubocop" do |ok, _|
      abort "\n❌  RuboCop failed — aborting publish." unless ok
    end
    puts "\n✅  RuboCop passed.\n"
  end

  desc "Run RSpec test suite"
  task :spec do
    puts "\n#{"=" * 60}"
    puts "  Running specs for #{GEM_NAME} v#{GEM_VERSION}"
    puts "=" * 60
    sh "bundle exec rspec --format documentation" do |ok, _|
      abort "\n❌  Specs failed — aborting publish." unless ok
    end
    puts "\n✅  All specs passed.\n"
  end

  desc "Build #{GEM_FILE}"
  task :build do
    puts "\n#{"=" * 60}"
    puts "  Building #{GEM_FILE}"
    puts "=" * 60
    sh "gem build #{GEMSPEC}" do |ok, _|
      abort "\n❌  Build failed." unless ok
    end
    puts "\n✅  Built: #{GEM_FILE}\n"

    puts "\n📦  Contents:"
    puts "-" * 40
    # Reads the .gem file directly, so it works on Windows too
    require "rubygems/package"
    Gem::Package.new(GEM_FILE).contents.sort.each { |file| puts file }
    puts "-" * 40
  end

  desc "Push #{GEM_FILE} to RubyGems.org"
  task :push do
    abort "❌  #{GEM_FILE} not found — run `rake publish:build` first." unless File.exist?(GEM_FILE)

    puts "\n#{"=" * 60}"
    puts "  Pushing #{GEM_FILE} to RubyGems.org"
    puts "=" * 60
    # MFA is required for this gem: gem push will ask for your OTP code here
    sh "gem push #{GEM_FILE}" do |ok, _|
      abort "\n❌  Push failed." unless ok
    end
    puts "\n🚀  #{GEM_NAME} v#{GEM_VERSION} published successfully!\n"
  end
end

# Full pipeline: lint -> spec -> build -> push
desc "Run lint and specs, build, and publish #{GEM_NAME} v#{GEM_VERSION} to RubyGems.org"
task publish: ["publish:lint", "publish:spec", "publish:build", "publish:push"] do
  puts "\n🎉  Done! #{GEM_NAME} v#{GEM_VERSION} is live on RubyGems.org\n"
end