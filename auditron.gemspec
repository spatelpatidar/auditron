# frozen_string_literal: true

require_relative "lib/auditron/version"

Gem::Specification.new do |spec|
  spec.name        = "auditron"
  spec.version     = Auditron::VERSION
  spec.authors     = ["Shailendra Kumar"]
  spec.email       = ["shailendrapatidar00@gmail.com"]

  spec.summary     = "Lightweight, diff-only audit logging for ActiveRecord models."
  spec.description = <<~DESC
    Auditron tracks who changed what on any ActiveRecord model — storing only
    the fields that changed, not full snapshots. Ships with a chainable query
    DSL, built-in log retention, a simple actor lambda, and works with
    PostgreSQL, MySQL, and SQLite. Zero hard dependencies beyond ActiveRecord.
  DESC

  spec.homepage    = "https://github.com/spatelpatidar/auditron"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.0.0"

  # Runtime
  spec.add_dependency "activerecord", ">= 7.0"

  # Development
  spec.add_development_dependency "rails",        ">= 7.0"
  spec.add_development_dependency "sqlite3",      "~> 2.1"
  spec.add_development_dependency "rspec",        "~> 3.0"
  spec.add_development_dependency "rspec-rails",  "~> 6.0"
  spec.add_development_dependency "rubocop",      "~> 1.0"
  spec.add_development_dependency "rubocop-rspec","~> 2.0"
  spec.add_development_dependency "simplecov", "~> 0.22"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/auditron/issues",
    "rubygems_mfa_required" => "true"
  }

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
