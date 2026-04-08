# frozen_string_literal: true

require "spec_helper"

RSpec.describe Auditron::AuditLog do
  let(:user)  { User.create!(email: "test@example.com", role: "user") }
  let(:admin) { Admin.create!(name: "Admin One") }

  def create_log(overrides = {})
    Auditron::AuditLog.create!({
      auditable_type: "User",
      auditable_id: user.id,
      action: "updated",
      changed_fields: { email: ["old@x.com", "new@x.com"] }.to_json,
      created_at: Time.now
    }.merge(overrides))
  end

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------

  describe "validations" do
    it "is valid with a valid action" do
      log = create_log(action: "created")
      expect(log).to be_persisted
    end

    it "is invalid without action" do
      log = Auditron::AuditLog.new(auditable_type: "User", auditable_id: 1)
      expect(log).not_to be_valid
      expect(log.errors[:action]).to be_present
    end

    it "is invalid with unknown action" do
      log = Auditron::AuditLog.new(
        auditable_type: "User",
        auditable_id: 1,
        action: "hacked"
      )
      expect(log).not_to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------

  describe ".for" do
    it "returns logs for a specific record" do
      user = User.create!(email: "test@example.com", role: "user")
      expect(Auditron::AuditLog.for(user).count).to eq(1)
    end

    it "does not return logs for other records" do
      user  = User.create!(email: "test@example.com", role: "user")
      other = User.create!(email: "other@example.com", role: "user")
      expect(Auditron::AuditLog.for(user).count).to eq(1)
      expect(Auditron::AuditLog.for(other).count).to eq(1)
    end
  end

  describe ".by" do
    it "returns logs by a specific actor" do
      create_log(actor_type: "Admin", actor_id: admin.id)
      expect(Auditron::AuditLog.by(admin).count).to eq(1)
    end
  end

  describe ".action" do
    it "filters by action" do
      create_log(action: "updated")
      create_log(action: "deleted")
      expect(Auditron::AuditLog.action(:updated).count).to eq(1)
    end
  end

  describe ".since" do
    it "returns logs after the given time" do
      Auditron::AuditLog.delete_all

      Auditron::AuditLog.create!(
        auditable_type: "User",
        auditable_id: 999,
        action: "updated",
        changed_fields: {}.to_json,
        created_at: 2.days.ago
      )

      Auditron::AuditLog.create!(
        auditable_type: "User",
        auditable_id: 999,
        action: "updated",
        changed_fields: {}.to_json,
        created_at: 10.days.ago
      )

      expect(Auditron::AuditLog.since(5.days.ago).count).to eq(1)
    end
  end

  describe "chaining scopes" do
    it "chains .by + .action + .since" do
      create_log(action: "deleted", actor_type: "Admin", actor_id: admin.id, created_at: 1.day.ago)
      create_log(action: "updated", actor_type: "Admin", actor_id: admin.id, created_at: 1.day.ago)
      result = Auditron::AuditLog.by(admin).action(:deleted).since(3.days.ago)
      expect(result.count).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # #changed_fields
  # ---------------------------------------------------------------------------

  describe "#changed_fields" do
    it "parses a JSON string into a Hash" do
      log = create_log(changed_fields: { email: ["a@x.com", "b@x.com"] }.to_json)
      expect(log.changed_fields).to eq("email" => ["a@x.com", "b@x.com"])
    end

    it "returns empty hash on invalid JSON" do
      log = create_log(changed_fields: "not-json")
      expect(log.changed_fields).to eq({})
    end

    it "returns value directly when already a Hash (skips JSON.parse)" do
      log = create_log(changed_fields: {}.to_json)
      allow(log).to receive(:[]).with(:changed_fields).and_return({ "role" => %w[user admin] })
      expect(log.changed_fields).to eq("role" => %w[user admin])
    end
  end

  # ---------------------------------------------------------------------------
  # #metadata
  # ---------------------------------------------------------------------------

  describe "#metadata" do
    it "returns nil when the metadata column is NULL" do
      log = create_log
      expect(log.metadata).to be_nil
    end

    it "parses a JSON string into a Hash" do
      log = create_log(metadata: { reason: "admin override" }.to_json)
      expect(log.metadata).to eq("reason" => "admin override")
    end

    it "returns value directly when already a Hash" do
      log = create_log
      allow(log).to receive(:[]).with(:metadata).and_return({ "key" => "val" })
      expect(log.metadata).to eq("key" => "val")
    end

    it "returns empty hash on invalid JSON" do
      log = create_log
      allow(log).to receive(:[]).with(:metadata).and_return("{{invalid}}")
      expect(log.metadata).to eq({})
    end
  end

  # ---------------------------------------------------------------------------
  # #summary
  # ---------------------------------------------------------------------------

  describe "#summary" do
    # summary uses `actor` (the AR association) for the nil check.
    # Since Admin is not wired as a polymorphic auditable actor in the test
    # schema, the association won't auto-load. We stub it where needed.

    it "includes auditable type and id" do
      log = create_log(action: "updated")
      expect(log.summary).to include("User ##{user.id}")
    end

    it "says 'anonymous' when actor columns are nil" do
      log = create_log(action: "deleted", actor_type: nil, actor_id: nil)
      expect(log.summary).to include("anonymous")
      expect(log.summary).to include("was deleted")
    end

    it "includes actor type and id when actor columns are populated" do
      log = create_log(actor_type: "Admin", actor_id: admin.id, action: "updated")
      # Stub the association so `actor` returns a truthy value
      allow(log).to receive(:actor).and_return(admin)
      expect(log.summary).to include("Admin ##{admin.id}")
      expect(log.summary).to include("was updated")
    end

    it "produces the correct full format when actor is present" do
      log = create_log(actor_type: "Admin", actor_id: admin.id, action: "created")
      allow(log).to receive(:actor).and_return(admin)
      expect(log.summary).to eq("User ##{user.id} was created by Admin ##{admin.id}")
    end

    it "produces the correct full format when actor is anonymous" do
      log = create_log(action: "created", actor_type: nil, actor_id: nil)
      expect(log.summary).to eq("User ##{user.id} was created by anonymous")
    end
  end
end
# # frozen_string_literal: true

# require "spec_helper"

# RSpec.describe Auditron::AuditLog do
#   let(:user)  { User.create!(email: "test@example.com", role: "user") }
#   let(:admin) { Admin.create!(name: "Admin One") }

#   def create_log(overrides = {})
#     Auditron::AuditLog.create!({
#       auditable_type: "User",
#       auditable_id: user.id,
#       action: "updated",
#       changed_fields: { email: ["old@x.com", "new@x.com"] }.to_json,
#       created_at: Time.now
#     }.merge(overrides))
#   end

#   describe "validations" do
#     it "is valid with a valid action" do
#       log = create_log(action: "created")
#       expect(log).to be_persisted
#     end

#     it "is invalid without action" do
#       log = Auditron::AuditLog.new(auditable_type: "User", auditable_id: 1)
#       expect(log).not_to be_valid
#       expect(log.errors[:action]).to be_present
#     end

#     it "is invalid with unknown action" do
#       log = Auditron::AuditLog.new(
#         auditable_type: "User",
#         auditable_id: 1,
#         action: "hacked"
#       )
#       expect(log).not_to be_valid
#     end
#   end

#   describe ".for" do
#     it "returns logs for a specific record" do
#       user = User.create!(email: "test@example.com", role: "user")
#       # after_create already wrote 1 log — no need to call create_log
#       expect(Auditron::AuditLog.for(user).count).to eq(1)
#     end

#     it "does not return logs for other records" do
#       user  = User.create!(email: "test@example.com", role: "user")
#       other = User.create!(email: "other@example.com", role: "user")
#       # each create fires after_create — user has 1 log, other has 1 log
#       expect(Auditron::AuditLog.for(user).count).to eq(1)
#       expect(Auditron::AuditLog.for(other).count).to eq(1)
#     end
#   end

#   describe ".by" do
#     it "returns logs by a specific actor" do
#       create_log(actor_type: "Admin", actor_id: admin.id)
#       expect(Auditron::AuditLog.by(admin).count).to eq(1)
#     end
#   end

#   describe ".action" do
#     it "filters by action" do
#       create_log(action: "updated")
#       create_log(action: "deleted")
#       expect(Auditron::AuditLog.action(:updated).count).to eq(1)
#     end
#   end

#   describe ".since" do
#     it "returns logs after the given time" do
#       Auditron::AuditLog.delete_all

#       # insert directly — no model, no after_create callback
#       Auditron::AuditLog.create!(
#         auditable_type: "User",
#         auditable_id: 999,
#         action: "updated",
#         changed_fields: {}.to_json,
#         created_at: 2.days.ago
#       )

#       Auditron::AuditLog.create!(
#         auditable_type: "User",
#         auditable_id: 999,
#         action: "updated",
#         changed_fields: {}.to_json,
#         created_at: 10.days.ago
#       )

#       expect(Auditron::AuditLog.since(5.days.ago).count).to eq(1)
#     end
#   end

#   describe "chaining scopes" do
#     it "chains .by + .action + .since" do
#       create_log(
#         action: "deleted",
#         actor_type: "Admin",
#         actor_id: admin.id,
#         created_at: 1.day.ago
#       )
#       create_log(
#         action: "updated",
#         actor_type: "Admin",
#         actor_id: admin.id,
#         created_at: 1.day.ago
#       )
#       result = Auditron::AuditLog
#                .by(admin)
#                .action(:deleted)
#                .since(3.days.ago)
#       expect(result.count).to eq(1)
#     end
#   end

#   describe "#changed_fields" do
#     it "parses JSON into a Hash" do
#       log = create_log(changed_fields: { email: ["a@x.com", "b@x.com"] }.to_json)
#       expect(log.changed_fields).to eq("email" => ["a@x.com", "b@x.com"])
#     end

#     it "returns empty hash on invalid JSON" do
#       log = create_log(changed_fields: "not-json")
#       expect(log.changed_fields).to eq({})
#     end
#   end
# end
