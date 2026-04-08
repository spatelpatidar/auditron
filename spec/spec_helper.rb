# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "lib/respondo/version.rb"
  add_filter "lib/respondo/railtie.rb"
  track_files "lib/**/*.rb"
end

require "auditron"
require_relative "support/database"
require_relative "support/models"

RSpec.configure do |config|
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  # Reset config and DB before each test
  config.before(:each) do
    Auditron.instance_variable_set(:@config, nil)
    Auditron::AuditLog.delete_all
    User.delete_all
    Post.delete_all
    Admin.delete_all
  end
end
