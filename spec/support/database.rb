# frozen_string_literal: true

require "active_record"
require "logger"

# Silent DB for CI, set AUDITRON_LOG=1 to see SQL
ActiveRecord::Base.logger = ENV["AUDITRON_LOG"] ? Logger.new($stdout) : nil

ActiveRecord::Base.establish_connection(
  adapter:  "sqlite3",
  database: ":memory:"
)

ActiveRecord::Schema.define do
  # audit_logs table — mirrors the migration template
  create_table :audit_logs, force: true do |t|
    t.string  :auditable_type, null: false
    t.bigint  :auditable_id,   null: false
    t.string  :action,         null: false
    t.text    :changed_fields
    t.string  :actor_type
    t.bigint  :actor_id
    t.string  :ip_address
    t.text    :metadata
    t.datetime :created_at,   null: false
  end

  add_index :audit_logs, [:auditable_type, :auditable_id]
  add_index :audit_logs, [:actor_type, :actor_id]
  add_index :audit_logs, :action
  add_index :audit_logs, :created_at

  # test models
  create_table :users, force: true do |t|
    t.string :email
    t.string :role
    t.string :status
    t.string :password_digest
    t.timestamps
  end

  create_table :admins, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :posts, force: true do |t|
    t.string :title
    t.text   :body
    t.timestamps
  end
end