# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "rails/generators"
require "rails/generators/active_record"
require "generators/auditron/install/install_generator"

RSpec.describe Auditron::Generators::InstallGenerator do
  # Build a bare generator instance with all Thor I/O silenced.
  # Uses a fixed temp path so no Dir.mktmpdir is needed inside examples.
  TMP_DEST = File.join(Dir.tmpdir, "auditron_generator_test")

  def build_generator
    FileUtils.mkdir_p(TMP_DEST)
    gen = described_class.new([], {}, destination_root: TMP_DEST)
    allow(gen).to receive(:say)
    allow(gen).to receive(:migration_template)
    gen
  end

  # ---------------------------------------------------------------------------
  # #confirm_install?
  # ---------------------------------------------------------------------------

  describe "#confirm_install?" do
    %w[y Y yes YES Yes].each do |input|
      it "returns true for #{input.inspect}" do
        gen = build_generator
        allow(gen).to receive(:ask).and_return(input)
        expect(gen.send(:confirm_install?)).to be true
      end
    end

    it "returns true for blank input (user pressed Enter)" do
      gen = build_generator
      allow(gen).to receive(:ask).and_return("  ")
      expect(gen.send(:confirm_install?)).to be true
    end

    %w[n N no NO nope anything].each do |input|
      it "returns false for #{input.inspect}" do
        gen = build_generator
        allow(gen).to receive(:ask).and_return(input)
        expect(gen.send(:confirm_install?)).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #display_banner
  # ---------------------------------------------------------------------------

  describe "#display_banner" do
    it "outputs the gem name" do
      gen = build_generator
      expect(gen).to receive(:say).with(/AUDITRON/, anything).at_least(:once)
      gen.send(:display_banner)
    end

    it "outputs the current VERSION" do
      gen = build_generator
      expect(gen).to receive(:say).with(/#{Regexp.escape(Auditron::VERSION)}/, anything).at_least(:once)
      gen.send(:display_banner)
    end
  end

  # ---------------------------------------------------------------------------
  # #display_intro
  # ---------------------------------------------------------------------------

  describe "#display_intro" do
    it "mentions audit_logs migration" do
      gen = build_generator
      expect(gen).to receive(:say).with(/audit_logs migration/, anything).at_least(:once)
      gen.send(:display_intro)
    end

    it "shows auditable usage example" do
      gen = build_generator
      expect(gen).to receive(:say).with(/auditable/, anything).at_least(:once)
      gen.send(:display_intro)
    end
  end

  # ---------------------------------------------------------------------------
  # #display_initializer_hint
  # ---------------------------------------------------------------------------

  describe "#display_initializer_hint" do
    it "tells the user to run rails db:migrate" do
      gen = build_generator
      expect(gen).to receive(:say).with(/rails db:migrate/, anything).at_least(:once)
      gen.send(:display_initializer_hint)
    end

    it "shows the Auditron.configure block" do
      gen = build_generator
      expect(gen).to receive(:say).with(/Auditron\.configure/, anything).at_least(:once)
      gen.send(:display_initializer_hint)
    end

    it "shows set_audit_actor controller example" do
      gen = build_generator
      expect(gen).to receive(:say).with(/set_audit_actor/, anything).at_least(:once)
      gen.send(:display_initializer_hint)
    end
  end

  # ---------------------------------------------------------------------------
  # #display_success
  # ---------------------------------------------------------------------------

  describe "#display_success" do
    it "says installed successfully" do
      gen = build_generator
      expect(gen).to receive(:say).with(/installed successfully/, anything).at_least(:once)
      gen.send(:display_success)
    end

    it "reminds user to run db:migrate" do
      gen = build_generator
      expect(gen).to receive(:say).with(/rails db:migrate/, anything).at_least(:once)
      gen.send(:display_success)
    end
  end

  # ---------------------------------------------------------------------------
  # #cancel_install
  # ---------------------------------------------------------------------------

  describe "#cancel_install" do
    it "outputs a cancellation message" do
      gen = build_generator
      expect(gen).to receive(:say).with(/Installation cancelled/, anything).at_least(:once)
      gen.send(:cancel_install)
    end

    it "tells user how to re-run the generator" do
      gen = build_generator
      expect(gen).to receive(:say).with(/rails generate auditron:install/, anything).at_least(:once)
      gen.send(:cancel_install)
    end
  end

  # ---------------------------------------------------------------------------
  # #install — full flow (YES)
  # ---------------------------------------------------------------------------

  describe "#install when user confirms" do
    it "calls migration_template with the correct arguments" do
      gen = build_generator
      allow(gen).to receive(:ask).and_return("y")
      expect(gen).to receive(:migration_template).with(
        "create_audit_logs.rb.erb",
        "db/migrate/create_audit_logs.rb"
      )
      gen.install
    end

    it "calls display_initializer_hint and display_success" do
      gen = build_generator
      allow(gen).to receive(:ask).and_return("y")
      expect(gen).to receive(:display_initializer_hint).and_call_original
      expect(gen).to receive(:display_success).and_call_original
      gen.install
    end

    it "does NOT call cancel_install" do
      gen = build_generator
      allow(gen).to receive(:ask).and_return("yes")
      expect(gen).not_to receive(:cancel_install)
      gen.install
    end
  end

  # ---------------------------------------------------------------------------
  # #install — full flow (NO / cancel)
  # ---------------------------------------------------------------------------

  describe "#install when user declines" do
    it "calls cancel_install" do
      gen = build_generator
      allow(gen).to receive(:ask).and_return("n")
      expect(gen).to receive(:cancel_install).and_call_original
      gen.install
    end

    it "does NOT call migration_template" do
      gen = build_generator
      allow(gen).to receive(:ask).and_return("n")
      expect(gen).not_to receive(:migration_template)
      gen.install
    end

    it "does NOT call display_success" do
      gen = build_generator
      allow(gen).to receive(:ask).and_return("n")
      expect(gen).not_to receive(:display_success)
      gen.install
    end
  end
end
