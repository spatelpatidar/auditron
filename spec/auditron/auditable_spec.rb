# frozen_string_literal: true

require "spec_helper"

RSpec.describe Auditron::Auditable do
  describe "after_create" do
    it "creates a log with action: created" do
      user = User.create!(email: "test@example.com", role: "user")
      log  = Auditron::AuditLog.for(user).last
      expect(log.action).to eq("created")
    end
  end

  describe "after_update" do
    it "logs only changed fields" do
      user = User.create!(email: "old@example.com", role: "user")
      Auditron::AuditLog.delete_all

      user.update!(email: "new@example.com")
      log = Auditron::AuditLog.for(user).last

      expect(log.action).to eq("updated")
      expect(log.changed_fields["email"]).to eq(["old@example.com", "new@example.com"])
    end

    it "does not log if no tracked fields changed" do
      user = User.create!(email: "test@example.com", role: "user")
      Auditron::AuditLog.delete_all

      # updated_at is in ignored_fields — touching only that should not log
      user.update_columns(updated_at: Time.now)
      expect(Auditron::AuditLog.for(user).count).to eq(0)
    end

    it "does not log ignored fields" do
      user = User.create!(email: "test@example.com", role: "user")
      Auditron::AuditLog.delete_all

      user.update!(email: "new@example.com")
      log = Auditron::AuditLog.for(user).last

      expect(log.changed_fields.keys).not_to include("updated_at", "created_at")
    end
  end

  describe "after_destroy" do
    it "creates a log with action: deleted" do
      user = User.create!(email: "test@example.com", role: "user")
      Auditron::AuditLog.delete_all

      user.destroy
      log = Auditron::AuditLog.for(user).last
      expect(log.action).to eq("deleted")
    end
  end

  describe "only: option" do
    it "logs only specified fields" do
      post = Post.create!(title: "Hello", body: "World")
      Auditron::AuditLog.delete_all

      post.update!(title: "Updated", body: "Changed body")
      log = Auditron::AuditLog.for(post).last

      expect(log.changed_fields.keys).to eq(["title"])
      expect(log.changed_fields.keys).not_to include("body")
    end
  end

  describe "actor" do
    it "stores actor when current_actor is set" do
      admin = Admin.create!(name: "Admin One")
      Auditron.configure { |c| c.current_actor = -> { admin } }

      user = User.create!(email: "test@example.com", role: "user")
      log  = Auditron::AuditLog.for(user).last

      expect(log.actor_id).to eq(admin.id)
      expect(log.actor_type).to eq("Admin")
    end

    it "stores nil actor when no current_actor configured" do
      user = User.create!(email: "test@example.com", role: "user")
      log  = Auditron::AuditLog.for(user).last

      expect(log.actor_id).to be_nil
      expect(log.actor_type).to be_nil
    end
  end
end