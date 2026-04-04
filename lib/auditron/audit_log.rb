# frozen_string_literal: true

module Auditron
  class AuditLog < ActiveRecord::Base
    self.table_name = "audit_logs"

    # Polymorphic — belongs to any audited model
    belongs_to :auditable, polymorphic: true, optional: true

    # Polymorphic — belongs to any actor (User, AdminUser, etc.)
    belongs_to :actor, polymorphic: true, optional: true

    validates :action, presence: true
    validates :action, inclusion: { in: %w[created updated deleted] }

    # -----------------------------------------------------------------------
    # Scopes
    # -----------------------------------------------------------------------

    # Filter by audited record
    # @example AuditLog.for(user)
    scope :for, ->(record) {
      where(auditable_type: record.class.name, auditable_id: record.id)
    }

    # Filter by actor
    # @example AuditLog.by(admin)
    scope :by, ->(actor) {
      where(actor_type: actor.class.name, actor_id: actor.id)
    }

    # Filter by action
    # @example AuditLog.action(:updated)
    scope :action, ->(action) { where(action: action.to_s) }

    # Filter by time
    # @example AuditLog.since(1.week.ago)
    scope :since, ->(time) { where("created_at >= ?", time) }

    # -----------------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------------

    def changed_fields
      value = self[:changed_fields]
      return value if value.is_a?(Hash)
      JSON.parse(value.to_s)
    rescue JSON::ParserError
      {}
    end

    def metadata
      value = self[:metadata]
      return nil if value.nil?
      return value if value.is_a?(Hash)
      JSON.parse(value.to_s)
    rescue JSON::ParserError
      {}
    end

    # Returns a human readable summary of the log entry
    # @example log.summary
    # => "Account #1 was updated by Account #2"
    def summary
      actor_info    = actor   ? "#{actor_type} ##{actor_id}"     : "anonymous"
      subject_info  = auditable ? "#{auditable_type} ##{auditable_id}" : "#{auditable_type} ##{auditable_id}"
      "#{subject_info} was #{action} by #{actor_info}"
    end
  end
end