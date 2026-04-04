# Changelog

All notable changes to Auditron will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

- Ruby `>= 3.0`
- ActiveRecord `>= 7.0`
- Rails `>= 7.0` (optional)
- PostgreSQL, MySQL, SQLite