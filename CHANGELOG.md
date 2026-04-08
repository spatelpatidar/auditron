# Changelog

All notable changes to Auditron will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.1] - 2026-04-08

### Fixed

- **Migration version hardcoded to `[7.0]`** — the generated `create_audit_logs`
  migration previously always inherited from `ActiveRecord::Migration[7.0]`
  regardless of the host application's Rails version. Running
  `rails generate auditron:install` on a Rails 7.1, 7.2, or 8.0 app would
  generate an incorrect migration class header.

  The generator now reads `ActiveRecord::VERSION::MAJOR` and
  `ActiveRecord::VERSION::MINOR` at generation time and injects the correct
  version bracket automatically:

  ```ruby
  # Before (hardcoded — wrong on Rails 7.1+)
  class CreateAuditLogs < ActiveRecord::Migration[7.0]

  # After (dynamic — always matches the host app)
  class CreateAuditLogs < ActiveRecord::Migration[7.1]   # on Rails 7.1
  class CreateAuditLogs < ActiveRecord::Migration[7.2]   # on Rails 7.2
  class CreateAuditLogs < ActiveRecord::Migration[8.0]   # on Rails 8.0
  ```

- **`ArgumentError: wrong number of arguments (given 3, expected 0)`** on
  `rails generate auditron:install` when running Rails 7.1+.

  Rails 7.1 removed the third positional options hash from `migration_template`.
  Passing `migration_version:` as a keyword argument to `migration_template`
  caused an `ArgumentError` crash immediately after the user confirmed
  installation — no files were created.

  The generator now sets `@migration_version` as an instance variable before
  calling `migration_template`, which makes it available inside the ERB
  template directly. This approach is compatible with Rails 6.0 through 8.x.

### Compatibility

This release is fully backwards-compatible. No changes to public API,
configuration, model DSL, or query interface.

---

## [1.0.0] - 2026-04-04

### Added

- **Core audit logging** — tracks `created`, `updated`, and `deleted` on any ActiveRecord model
- **Diff-only storage** — stores only changed fields with before/after values, not full snapshots
- **`auditable` DSL** — include `Auditron::Auditable` and call `auditable` on any model
  - `auditable` — track all fields
  - `auditable only: [:email, :role]` — track specific fields only
  - `auditable except: [:last_sign_in_at]` — exclude specific fields
- **Thread-safe actor tracking** — set `Auditron.current_actor = @current_user` in any controller
  - Works with JWT, Devise, session-based auth, or any custom auth system
  - Automatically cleared after every request — no leaking between requests
- **Custom metadata** — attach any extra context to a log entry via `audit_with`
  - `account.audit_with(reason: "GDPR request").destroy`
  - Stored as JSON, returned as Hash
- **Chainable query DSL** on `Auditron::AuditLog`
  - `.for(record)` — all logs for a specific record
  - `.by(actor)` — all changes made by a specific actor
  - `.action(:updated)` — filter by action
  - `.since(1.week.ago)` — filter by time
  - Fully chainable: `.by(admin).action(:deleted).since(1.week.ago)`
- **`log.actor`** — polymorphic association returns the full actor object directly
- **`log.summary`** — human readable description e.g. `"Account #8 was updated by Account #1"`
- **`log.changed_fields`** — parses JSON automatically, returns Hash
- **`log.metadata`** — parses JSON automatically, returns Hash or nil
- **Built-in log retention** via `config.retention_days`
  - `Auditron::Sweeper.purge!` — deletes all logs older than configured retention days
  - Safe to call from Sidekiq, GoodJob, cron, or any background job
- **Request IP tracking** — opt-in via `config.store_ip = true`
  - Handled automatically by Rack middleware — no extra setup needed
- **Global ignored fields** — `config.ignored_fields` excludes fields across all models
- **Install generator** — `rails generate auditron:install`
  - Interactive CLI with step-by-step guidance
  - Generates `audit_logs` migration with indexes
  - Shows next steps after install
- **Migration** — creates `audit_logs` table with indexes on
  `auditable`, `actor`, `action`, and `created_at`
- **Railtie** — auto-integrates into Rails apps, no manual setup needed
- **Database agnostic** — works with PostgreSQL, MySQL, and SQLite
- **Zero hard dependencies** beyond `activerecord`
- **Rails optional** — works in plain Ruby + ActiveRecord projects

### Notes

- `actor_type` and `actor_id` will be `nil` on unauthenticated requests
  (e.g. signup) — this is correct behavior, not a bug
- Do not set `current_actor` in the initializer — set it in the controller
  after authentication so the actor is always the authenticated user

---

## Compatibility

| Version | Ruby    | ActiveRecord | Rails         | Databases                  |
|---------|---------|--------------|---------------|----------------------------|
| 1.0.1   | >= 3.0  | >= 7.0       | >= 7.0 (opt.) | PostgreSQL, MySQL, SQLite  |
| 1.0.0   | >= 3.0  | >= 7.0       | >= 7.0 (opt.) | PostgreSQL, MySQL, SQLite  |