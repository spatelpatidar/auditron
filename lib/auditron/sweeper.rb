# frozen_string_literal: true

module Auditron
  module Sweeper
    # Delete all logs older than config.retention_days
    # Call this from a scheduled job e.g. daily Sidekiq/GoodJob cron
    #
    # @example
    #   Auditron::Sweeper.purge!
    def self.purge!
      days = Auditron.config.retention_days
      return unless days.is_a?(Integer) && days.positive?

      cutoff = Time.current - days.days
      deleted = Auditron::AuditLog.where("created_at < ?", cutoff).delete_all
      deleted
    end
  end
end