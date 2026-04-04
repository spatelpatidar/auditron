# frozen_string_literal: true

require "spec_helper"

RSpec.describe Auditron::Sweeper do
  def create_log(created_at:)
    Auditron::AuditLog.create!(
      auditable_type: "User",
      auditable_id:   1,
      action:         "updated",
      changed_fields: {}.to_json,
      created_at:     created_at
    )
  end

  describe ".purge!" do
    context "when retention_days is set" do
      before { Auditron.configure { |c| c.retention_days = 30 } }

      it "deletes logs older than retention_days" do
        create_log(created_at: 31.days.ago)
        create_log(created_at: 10.days.ago)

        expect { Auditron::Sweeper.purge! }
          .to change { Auditron::AuditLog.count }.from(2).to(1)
      end

      it "returns the number of deleted records" do
        create_log(created_at: 31.days.ago)
        create_log(created_at: 32.days.ago)

        expect(Auditron::Sweeper.purge!).to eq(2)
      end

      it "keeps logs within retention window" do
        create_log(created_at: 10.days.ago)
        Auditron::Sweeper.purge!
        expect(Auditron::AuditLog.count).to eq(1)
      end
    end

    context "when retention_days is nil" do
      before { Auditron.configure { |c| c.retention_days = nil } }

      it "does nothing" do
        create_log(created_at: 365.days.ago)
        expect { Auditron::Sweeper.purge! }
          .not_to change { Auditron::AuditLog.count }
      end
    end

    context "when retention_days is zero or negative" do
      it "does nothing for zero" do
        Auditron.configure { |c| c.retention_days = 0 }
        create_log(created_at: 1.day.ago)
        expect { Auditron::Sweeper.purge! }
          .not_to change { Auditron::AuditLog.count }
      end
    end
  end
end