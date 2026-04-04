# frozen_string_literal: true

module Auditron
  class Configuration
    # Lambda that returns the current actor
    # @example config.current_actor = -> { Current.user }
    attr_accessor :current_actor

    # Fields to never log across all models
    # @example config.ignored_fields = [:updated_at, :created_at]
    attr_accessor :ignored_fields

    # When true, stores request IP in every log entry
    attr_accessor :store_ip

    # Auto-purge logs older than N days. nil = keep forever
    attr_accessor :retention_days

    def initialize
      @current_actor  = -> { nil }
      @ignored_fields = %i[updated_at created_at]
      @store_ip       = false
      @retention_days = nil
    end
  end
end