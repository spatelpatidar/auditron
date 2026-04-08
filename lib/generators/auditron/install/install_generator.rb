# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Auditron
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def install
        display_banner
        display_intro
        return cancel_install unless confirm_install?

        say ""
        say "  Creating migration...", :cyan

        # Set migration version as instance variable so the ERB template
        # can read it via @migration_version.
        # This is required for Rails 7.1+ where migration_template no longer
        # accepts a third options hash argument.
        @migration_version = migration_version

        migration_template(
          "create_audit_logs.rb.erb",
          "db/migrate/create_audit_logs.rb"
        )
        say ""

        display_initializer_hint
        display_success
      end

      private

      def display_banner
        say ""
        say "  +===================================================+", :cyan
        say "  |                                                   |", :cyan
        say "  |       AUDITRON  --  Audit Logging Gem             |", :cyan
        say "  |                    v#{Auditron::VERSION.ljust(6)}                        |", :cyan
        say "  |                                                   |", :cyan
        say "  +===================================================+", :cyan
        say ""
      end

      def display_intro
        say "  Auditron will set up audit logging for your Rails app.", :white
        say ""
        say "  This installer will:", :white
        say ""
        say "    [+]  Create the audit_logs migration", :green
        say "    [+]  Add indexes for fast querying", :green
        say "    [+]  Track: auditable, actor, action, changed fields, IP", :green
        say ""
        say "  ---------------------------------------------------", :cyan
        say ""
        say "  After install, add to any model:", :yellow
        say ""
        say "    class User < ApplicationRecord", :white
        say "      auditable only: [:email, :role, :status]", :green
        say "    end", :white
        say ""
        say "  ---------------------------------------------------", :cyan
        say ""
      end

      def confirm_install?
        answer = ask(
          "  Ready to install? This will create the audit_logs migration. [Y/n]:",
          :yellow
        ).strip.downcase

        answer == "y" || answer == "yes" || answer == ""
      end

      def display_initializer_hint
        say "  ---------------------------------------------------", :cyan
        say ""
        say "  Next steps:", :white
        say ""
        say "    1.  Run the migration:", :yellow
        say "          rails db:migrate", :green
        say ""
        say "    2.  Create config/initializers/auditron.rb:", :yellow
        say "          Auditron.configure do |config|", :green
        say "            config.ignored_fields = %i[updated_at created_at]", :green
        say "            config.store_ip       = false", :green
        say "            config.retention_days = nil", :green
        say "          end", :green
        say ""
        say "    3.  Set current actor in ApplicationController:", :yellow
        say "          before_action :set_audit_actor", :green
        say "          def set_audit_actor", :green
        say "            Auditron.current_actor = @current_user", :green
        say "          end", :green
        say ""
        say "    4.  Add auditable to your models:", :yellow
        say "          auditable only: [:email, :role]", :green
        say ""
        say "    5.  Query your logs:", :yellow
        say "          user.audit_logs", :green
        say "          AuditLog.by(admin).action(:deleted).since(1.week.ago)", :green
        say ""
        say "  ---------------------------------------------------", :cyan
        say ""
      end

      def display_success
        say "  [OK]  Auditron installed successfully!", :green
        say "  [OK]  Run 'rails db:migrate' to complete setup.", :green
        say ""
        say "  Happy auditing!", :cyan
        say ""
      end

      def cancel_install
        say ""
        say "  [CANCELLED]  Installation cancelled.", :red
        say "  Run 'rails generate auditron:install' again when ready.", :yellow
        say ""
      end

      # Returns the Rails migration version bracket e.g. "[7.1]" or "[8.0]".
      # Uses the host app's actual ActiveRecord version so the migration class
      # always inherits from the correct base version.
      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end