# frozen_string_literal: true

require "spec_helper"

RSpec.describe Auditron::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "sets default_success_message to nil actor" do
      expect(config.current_actor.call).to be_nil
    end

    it "ignores updated_at and created_at by default" do
      expect(config.ignored_fields).to include(:updated_at, :created_at)
    end

    it "disables store_ip by default" do
      expect(config.store_ip).to be false
    end

    it "sets retention_days to nil by default" do
      expect(config.retention_days).to be_nil
    end
  end

  describe "configure block" do
    before do
      Auditron.configure do |c|
        c.current_actor  = -> { "test_actor" }
        c.ignored_fields = [:updated_at]
        c.store_ip       = true
        c.retention_days = 30
      end
    end

    it "sets current_actor" do
      expect(Auditron.config.current_actor.call).to eq("test_actor")
    end

    it "sets ignored_fields" do
      expect(Auditron.config.ignored_fields).to eq([:updated_at])
    end

    it "sets store_ip" do
      expect(Auditron.config.store_ip).to be true
    end

    it "sets retention_days" do
      expect(Auditron.config.retention_days).to eq(30)
    end
  end
end