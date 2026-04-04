# frozen_string_literal: true

require "active_record"
require "active_support/core_ext/module/attribute_accessors_per_thread"
require "auditron/version"
require "auditron/configuration"
require "auditron/audit_log"
require "auditron/auditable"
require "auditron/sweeper"

module Auditron
  # Explicitly require active_support thread accessor
  thread_mattr_accessor :current_actor
  thread_mattr_accessor :current_request

  class << self
    def configure
      yield config
    end

    def config
      @config ||= Configuration.new
    end
  end
end

require "auditron/railtie" if defined?(Rails::Railtie)