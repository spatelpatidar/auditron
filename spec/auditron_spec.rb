# frozen_string_literal: true

require "spec_helper"

RSpec.describe Auditron do
  describe "VERSION" do
    it "has a version number" do
      expect(Auditron::VERSION).not_to be_nil
    end

    it "is a string" do
      expect(Auditron::VERSION).to be_a(String)
    end

    it "follows semantic versioning" do
      expect(Auditron::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe ".config" do
    it "returns a Configuration instance" do
      expect(Auditron.config).to be_a(Auditron::Configuration)
    end

    it "returns the same instance on multiple calls" do
      expect(Auditron.config).to equal(Auditron.config)
    end
  end

  describe ".configure" do
    it "yields the config object" do
      expect { |b| Auditron.configure(&b) }.to yield_with_args(Auditron::Configuration)
    end

    it "persists changes made in the block" do
      Auditron.configure { |c| c.store_ip = true }
      expect(Auditron.config.store_ip).to be true
    end
  end

  describe "autoloading" do
    it "loads Configuration" do
      expect(defined?(Auditron::Configuration)).to eq("constant")
    end

    it "loads AuditLog" do
      expect(defined?(Auditron::AuditLog)).to eq("constant")
    end

    it "loads Auditable" do
      expect(defined?(Auditron::Auditable)).to eq("constant")
    end

    it "loads Sweeper" do
      expect(defined?(Auditron::Sweeper)).to eq("constant")
    end
  end
end
