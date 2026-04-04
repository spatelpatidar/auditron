# Auditron

> Lightweight, diff-only audit logging for ActiveRecord models.

---

## Why Auditron?

You shipped your Rails API. Users are complaining that their data changed without explanation.
Your manager wants a compliance report. Your security team needs to know who deleted that record.

**You have no idea. Because you never tracked it.**

Most developers reach for `paper_trail` at this point. It works — but it stores a **full snapshot
of every object on every change**. Change one column on a User with 30 attributes? paper_trail
writes all 30 to the database. Do that a thousand times a day and you have a serious DB bloat problem.

`audited` is the other popular choice. But its actor system is clunky, it has no built-in log
retention, and customization always feels like fighting the gem.

`logidze` is great — if you're on PostgreSQL. MySQL or SQLite users are out of luck.

**Auditron was built to fix all of this:**

| Problem | How Auditron solves it |
|---------|----------------------|
| DB bloat from full snapshots | Stores **only changed fields** — `{ email: ["old", "new"] }` |
| Clunky actor wiring | One line in your controller — works with any auth system |
| No log cleanup | Built-in retention: `config.retention_days = 90` |
| PostgreSQL lock-in | Works with PostgreSQL, MySQL, and SQLite |
| No query interface | Chainable DSL: `AuditLog.by(admin).action(:deleted).since(1.week.ago)` |
| Too many dependencies | Only hard dependency is `activerecord` |

---

## Who needs this?

- Any SaaS app that needs to answer **"who changed this, and when?"**
- Apps under **GDPR, HIPAA, or SOC2** compliance requirements
- Teams that want audit trails without the overhead of a full versioning system
- APIs built with [Respondo](https://github.com/shailendrapatidar/respondo) that want request + change tracking

---

## At a glance

```ruby
class Account < ApplicationRecord
  include Auditron::Auditable
  auditable only: [:email, :role, :status]
end

# someone updates their profile...
account.update!(first_name: "Jane")

# now you know exactly what happened
account.audit_logs.last
# => #<AuditLog
#      action:         "updated"
#      changed_fields: { "first_name" => ["John", "Jane"] }
#      actor_type:     "Account"
#      actor_id:       1
#      ip_address:     "192.168.1.1"
#      created_at:     "2026-04-04T08:00:00Z"
#    >
```

---

## Installation

Add to your Gemfile:

```ruby
gem "auditron"
```

Then run:

```bash
bundle install
```

Generate and run the migration:

```bash
rails generate auditron:install
rails db:migrate
```

---

## Configuration

Create an initializer at `config/initializers/auditron.rb`:

```ruby
Auditron.configure do |config|
  # Fields to never log across all models
  config.ignored_fields = %i[updated_at created_at]

  # Include request IP in every log entry (default: false)
  config.store_ip = true

  # Auto-purge logs older than N days (default: nil — keep forever)
  # Call Auditron::Sweeper.purge! from a scheduled job
  config.retention_days = 90
end
```

> **Note:** Do not set `current_actor` in the initializer.
> Instance variables like `@current_user` are not available there —
> they only exist during a request. See Controller Setup below.

---

## Controller Setup

Auditron needs to know who is making changes. Set the current actor
in your `ApplicationController` — works with **any auth system**.

Auditron stores it in a **thread-safe variable** and clears it
automatically after every request. Safe for Puma and any threaded server.

### JWT (API apps)

```ruby
class ApplicationController < ActionController::API
  private

  def authenticate_account!
    token   = request.headers["Authorization"]&.split(" ")&.last
    payload = JsonAuthToken.decode(token)
    @current_user = Account.find_by(id: payload[:account_id])

    render_unauthorized(message: "Invalid token") and return unless @current_user

    # Set the actor — Auditron reads this on every model change
    Auditron.current_actor = @current_user
  end
end
```

### Devise

```ruby
class ApplicationController < ActionController::Base
  before_action :set_audit_actor

  private

  def set_audit_actor
    Auditron.current_actor = current_user
  end
end
```

### Session based (no Devise)

```ruby
class ApplicationController < ActionController::Base
  before_action :set_audit_actor

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def set_audit_actor
    Auditron.current_actor = current_user
  end
end
```

### No actor (background jobs, rake tasks, seeds)

```ruby
# Actor will be nil — Auditron handles this gracefully
# actor_type: nil, actor_id: nil in the log entry
Auditron.current_actor = nil
```

> **Important:** On signup or any unauthenticated request, `actor_type`
> and `actor_id` will be `nil` — this is correct behavior.
> The user does not exist yet so there is no actor to record.

---

## Usage

### Track all changes on a model

```ruby
class Account < ApplicationRecord
  include Auditron::Auditable
  auditable
end
```

### Track only specific fields

```ruby
class Account < ApplicationRecord
  include Auditron::Auditable
  auditable only: [:email, :role, :status]
end
```

### Exclude specific fields

```ruby
class Account < ApplicationRecord
  include Auditron::Auditable
  auditable except: [:last_sign_in_at, :login_count]
end
```

### Attach custom metadata to a log entry

Pass any extra context you want stored alongside the log:

```ruby
# Simple reason
account.audit_with(reason: "user requested name change").update!(first_name: "Jane")

# Support ticket reference
account.audit_with(
  reason: "admin override",
  ticket: "SUPPORT-1234",
  note:   "user forgot old email"
).update!(email: "new@example.com")

# GDPR deletion
account.audit_with(reason: "GDPR deletion request").destroy
```

Metadata is stored as JSON and returned as a Hash:

```ruby
account.audit_logs.last.metadata
# => { "reason" => "admin override", "ticket" => "SUPPORT-1234" }
```

---

## Querying audit logs

```ruby
# All logs for a specific record
account.audit_logs

# Same, via class method
Auditron::AuditLog.for(account)

# All changes made by a specific actor
Auditron::AuditLog.by(admin)

# Filter by action
Auditron::AuditLog.action(:updated)
Auditron::AuditLog.action(:deleted)
Auditron::AuditLog.action(:created)

# Filter by time
Auditron::AuditLog.since(1.week.ago)
Auditron::AuditLog.since(1.month.ago)

# Chain them
Auditron::AuditLog.by(admin).action(:deleted).since(1.week.ago)

# Get actor object directly from log
log = account.audit_logs.last
log.actor        # => full Account/User/Admin object
log.actor_type   # => "Account"
log.actor_id     # => 1

# Human readable summary
log.summary
# => "Account #8 was updated by Account #1"
```

---

## Log retention (Sweeper)

Auto-purge old logs using a scheduled job:

```ruby
# config/initializers/auditron.rb
config.retention_days = 90  # keep logs for 90 days

# Call from a scheduled job (Sidekiq, GoodJob, cron)
Auditron::Sweeper.purge!  # deletes all logs older than retention_days
```

Example with a background job:

```ruby
class AuditLogCleanupJob < ApplicationJob
  def perform
    Auditron::Sweeper.purge!
  end
end
```

---

## Log entry structure

Every `AuditLog` record contains:

| Field | Type | Description |
|-------|------|-------------|
| `auditable_type` | String | Model class name e.g. `"Account"` |
| `auditable_id` | Integer | Record ID |
| `action` | String | `created`, `updated`, or `deleted` |
| `changed_fields` | JSON | Only changed fields with before/after values |
| `actor_id` | Integer | ID of the actor who made the change |
| `actor_type` | String | Class name of the actor e.g. `"Account"` |
| `ip_address` | String | Request IP (when `store_ip: true`) |
| `metadata` | JSON | Custom data attached via `audit_with` |
| `created_at` | DateTime | When the change happened |

### Example log entry

```ruby
#<Auditron::AuditLog
  id:             7,
  auditable_type: "Account",
  auditable_id:   8,
  action:         "updated",
  changed_fields: { "first_name" => ["John", "Jane"] },
  actor_type:     "Account",
  actor_id:       1,
  ip_address:     "::1",
  metadata:       { "reason" => "user requested name change" },
  created_at:     Sat, 04 Apr 2026 13:38:08 UTC
>
```

---

## How it compares

| Feature | Auditron | paper_trail | audited | logidze |
|---------|----------|-------------|---------|---------|
| Diff-only storage | ✅ | ❌ full snapshots | ✅ | ✅ |
| MySQL support | ✅ | ✅ | ✅ | ❌ |
| SQLite support | ✅ | ✅ | ✅ | ❌ |
| Built-in retention | ✅ | ❌ | ❌ | ❌ |
| Chainable query DSL | ✅ | ❌ | ❌ | ❌ |
| Custom metadata | ✅ | ❌ | ❌ | ❌ |
| Simple actor config | ✅ | ⚠️ | ⚠️ | ✅ |
| Rails required | ❌ | ✅ | ✅ | ✅ |

---

## Compatibility

- Ruby `>= 3.0`
- ActiveRecord `>= 7.0`
- Rails `>= 7.0` (optional — works without Rails)
- PostgreSQL, MySQL, SQLite

---

## Contributing

Bug reports and pull requests are welcome on GitHub.

---

## License

MIT