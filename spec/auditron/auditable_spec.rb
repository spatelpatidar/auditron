# frozen_string_literal: true

require "spec_helper"

RSpec.describe Auditron::Auditable do
  # ---------------------------------------------------------------------------
  # after_create
  # ---------------------------------------------------------------------------

  describe "after_create" do
    it "creates a log with action: created" do
      user = User.create!(email: "test@example.com", role: "user")
      log  = Auditron::AuditLog.for(user).last
      expect(log.action).to eq("created")
    end
  end

  # ---------------------------------------------------------------------------
  # after_update
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # after_destroy
  # ---------------------------------------------------------------------------

  describe "after_destroy" do
    it "creates a log with action: deleted" do
      user = User.create!(email: "test@example.com", role: "user")
      Auditron::AuditLog.delete_all

      user.destroy
      log = Auditron::AuditLog.for(user).last
      expect(log.action).to eq("deleted")
    end
  end

  # ---------------------------------------------------------------------------
  # only: option
  # ---------------------------------------------------------------------------

  describe "only: option" do
    it "logs only specified fields" do
      post = Post.create!(title: "Hello", body: "World")
      Auditron::AuditLog.delete_all

      post.update!(title: "Updated", body: "Changed body")
      log = Auditron::AuditLog.for(post).last

      expect(log.changed_fields.keys).to eq(["title"])
      expect(log.changed_fields.keys).not_to include("body")
    end

    it "does not write a log when only-tracked fields are unchanged" do
      post = Post.create!(title: "Hello", body: "World")
      Auditron::AuditLog.delete_all

      post.update!(body: "New body only")
      expect(Auditron::AuditLog.for(post).count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # except: option
  # ---------------------------------------------------------------------------

  describe "except: option" do
    before(:all) do
      unless defined?(ExceptPost)
        Object.const_set("ExceptPost", Class.new(ActiveRecord::Base) do
          self.table_name = "posts"
          include Auditron::Auditable
          auditable except: [:body]
        end)
      end
    end

    it "logs fields NOT in the except list" do
      post = ExceptPost.create!(title: "Hello", body: "World")
      Auditron::AuditLog.delete_all

      post.update!(title: "New title", body: "New body")
      log = Auditron::AuditLog.for(post).last

      expect(log.changed_fields.keys).to include("title")
      expect(log.changed_fields.keys).not_to include("body")
    end

    it "does not log fields in the except list" do
      post = ExceptPost.create!(title: "Hello", body: "World")
      Auditron::AuditLog.delete_all

      post.update!(body: "Only body changes")
      expect(Auditron::AuditLog.for(post).count).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # actor
  # ---------------------------------------------------------------------------

  describe "actor" do
    it "stores actor when current_actor is set via lambda" do
      admin = Admin.create!(name: "Admin One")
      # Reset config so lambda is the only actor source
      Auditron.current_actor = nil
      Auditron.configure { |c| c.current_actor = -> { admin } }

      user = User.create!(email: "test@example.com", role: "user")
      log  = Auditron::AuditLog.for(user).last

      expect(log.actor_id).to eq(admin.id)
      expect(log.actor_type).to eq("Admin")
    end

    it "prefers thread-local current_actor over config lambda" do
      admin1 = Admin.create!(name: "Lambda Actor")
      admin2 = Admin.create!(name: "Thread Actor")

      Auditron.configure { |c| c.current_actor = -> { admin1 } }
      Auditron.current_actor = admin2

      user = User.create!(email: "test@example.com", role: "user")
      log  = Auditron::AuditLog.for(user).last

      expect(log.actor_id).to eq(admin2.id)
      expect(log.actor_type).to eq("Admin")
    end

    it "stores nil when config lambda raises an error" do
      Auditron.configure { |c| c.current_actor = -> { raise "boom" } }

      user = User.create!(email: "test@example.com", role: "user")
      log  = Auditron::AuditLog.for(user).last

      expect(log.actor_id).to be_nil
      expect(log.actor_type).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # #audit_with — metadata
  # ---------------------------------------------------------------------------

  describe "#audit_with" do
    it "returns self so calls can be chained before save" do
      user = User.create!(email: "test@example.com", role: "user")
      Auditron::AuditLog.delete_all

      result = user.audit_with(reason: "test")
      expect(result).to eq(user)
    end

    it "stores metadata on the resulting audit log" do
      user = User.create!(email: "test@example.com", role: "user")
      Auditron::AuditLog.delete_all

      user.audit_with(reason: "admin override").update!(email: "meta@example.com")
      log = Auditron::AuditLog.for(user).last

      expect(log.metadata).to eq("reason" => "admin override")
    end

    it "clears metadata after the write so it does not leak to subsequent operations" do
      user = User.create!(email: "test@example.com", role: "user")
      Auditron::AuditLog.delete_all

      user.audit_with(reason: "one-time").update!(email: "first@example.com")
      user.update!(email: "second@example.com")

      logs = Auditron::AuditLog.for(user).order(:id)
      expect(logs.first.metadata).to eq("reason" => "one-time")
      expect(logs.last.metadata).to be_nil
    end

    it "stores nil metadata when audit_with is not called" do
      user = User.create!(email: "test@example.com", role: "user")
      log  = Auditron::AuditLog.for(user).last
      expect(log.metadata).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # IP address
  # ---------------------------------------------------------------------------

  describe "IP address" do
    context "when store_ip is false (default)" do
      it "stores nil ip_address" do
        user = User.create!(email: "test@example.com", role: "user")
        log  = Auditron::AuditLog.for(user).last
        expect(log.ip_address).to be_nil
      end
    end

    context "when store_ip is true but current_request is nil" do
      before { Auditron.configure { |c| c.store_ip = true } }

      it "stores nil ip_address" do
        Auditron.current_request = nil
        user = User.create!(email: "test@example.com", role: "user")
        log  = Auditron::AuditLog.for(user).last
        expect(log.ip_address).to be_nil
      end
    end

    context "when store_ip is true and current_request is present" do
      before { Auditron.configure { |c| c.store_ip = true } }

      it "stores the remote IP from the request" do
        Auditron.current_request = double("request", remote_ip: "1.2.3.4")
        user = User.create!(email: "test@example.com", role: "user")
        log  = Auditron::AuditLog.for(user).last
        expect(log.ip_address).to eq("1.2.3.4")
      end
    end
  end
end
