# frozen_string_literal: true

module Auditron
  module Auditable
    extend ActiveSupport::Concern

    included do
      # Stores options passed to auditable — :only, :except
      class_attribute :_auditron_options, default: {}

      has_many :audit_logs,
               class_name:  "Auditron::AuditLog",
               as:          :auditable,
               dependent:   :destroy
    end

    class_methods do
      # @param only   [Array<Symbol>] track only these fields
      # @param except [Array<Symbol>] track all fields except these
      def auditable(only: nil, except: nil)
        self._auditron_options = { only: only, except: except }

        after_create  :auditron_log_create
        after_update  :auditron_log_update
        after_destroy :auditron_log_destroy
      end
    end

    # Dev calls this manually to attach metadata to the next audit log
    # @example account.audit_with(reason: "admin override")
    def audit_with(metadata = {})
      @_auditron_metadata = metadata
      self
    end

    private

    def auditron_log_create
      write_audit_log("created", {})
    end

    def auditron_log_update
      diff = filtered_changes
      return if diff.empty?
      write_audit_log("updated", diff)
    end

    def auditron_log_destroy
      write_audit_log("deleted", {})
    end

    def write_audit_log(action, changed_fields)
      actor = resolve_actor
      metadata = @_auditron_metadata.presence

      Auditron::AuditLog.create!(
        auditable:      self,
        action:         action,
        changed_fields: changed_fields.to_json,
        actor_id:       actor&.respond_to?(:id) ? actor.id : nil,
        actor_type:     actor&.class&.name,
        ip_address:     resolve_ip,
        metadata: metadata&.to_json
      )
    ensure
      # Always clear after write — prevents metadata leaking to next operation
      @_auditron_metadata = nil
    end

    # Build a diff hash of only the fields that changed
    # Format: { field: [old_value, new_value] }
    def filtered_changes
      opts            = self.class._auditron_options
      global_ignored  = Auditron.config.ignored_fields.map(&:to_s)
      raw_changes     = saved_changes.except(*global_ignored)

      # Apply :only filter
      if opts[:only].present?
        allowed = opts[:only].map(&:to_s)
        raw_changes = raw_changes.slice(*allowed)
      end

      # Apply :except filter
      if opts[:except].present?
        excluded = opts[:except].map(&:to_s)
        raw_changes = raw_changes.except(*excluded)
      end

      raw_changes
    end

    def resolve_actor
      # Priority 1: thread-local set directly in controller
      return Auditron.current_actor if Auditron.current_actor

      # Priority 2: lambda fallback from config
      Auditron.config.current_actor&.call
    rescue StandardError
      nil
    end

    def resolve_ip
      return nil unless Auditron.config.store_ip
      Auditron.current_request&.remote_ip
    end
  end
end