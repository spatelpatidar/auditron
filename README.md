# Auditron


[![Gem Version](https://badge.fury.io/rb/auditron.svg?icon=si%3Arubygems&icon_color=%23ce0303)](https://badge.fury.io/rb/auditron)
![GitHub Repo Views](https://gitviews.com/repo/spatelpatidar/auditron.svg)
> Audit logging for API-first Rails apps — built-in retention, flexible actor tracking, and a clean query DSL.

---

## Why Auditron?

Most audit gems were built for traditional Rails apps with session-based auth.
If you are building an API with JWT, service objects, or background jobs — they
get in your way fast.

`paper_trail` stores full object snapshots on every change. Change one column
on a model with 30 attributes and it writes all 30 to the database, every time.
At scale, this becomes a serious storage problem.

`audited` and `paper_trail` both assume controller-based actor tracking tied to
`current_user` — which does not exist in JWT or service-layer contexts.

Neither gem ships with log retention. You always end up writing your own cleanup job.

**Auditron was designed for how modern Rails APIs are actually built:**

- JWT and service-layer friendly — set the actor anywhere, not just in controllers
- Diff-only storage — stores only what changed, not the full object
- Built-in retention — configure once, run a job, logs clean themselves up
- Chainable query DSL — find exactly what you need without writing raw SQL

---

## Who needs this?

- API-first Rails apps using JWT or token-based auth
- Apps under **GDPR, HIPAA, or SOC2** compliance requirements that need audit trails
- Teams tired of paper_trail bloating their database
- Apps that need to answer **"who changed this, when, and why?"**

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
in your controller after authentication — works with **any auth system**.

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

    render json: { error: "Invalid token" }, status: :unauthorized and return unless @current_user

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

### Service objects or background jobs

```ruby
# Set and clear manually — Auditron does not clear this automatically
# outside of a request cycle
Auditron.current_actor = admin_user
account.update!(status: "suspended")
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

No other major audit gem ships with built-in log retention.
Configure once and run from any scheduled job:

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

This is an honest comparison. Every gem has strengths — pick the right tool for your use case.

| Feature | Auditron | PaperTrail | Audited | Logidze |
|---------|----------|------------|---------|---------|
| Storage model | Diff only | Full snapshot | Diff (changes) | Diff (JSONB) |
| PostgreSQL | ✅ | ✅ | ✅ | ✅ |
| MySQL | ✅ | ✅ | ✅ | ❌ |
| SQLite | ✅ | ✅ | ✅ | ❌ |
| Built-in retention | ✅ | ❌ | ❌ | ❌ |
| Custom metadata | ✅ clean DSL | ⚠️ via `meta` config | ⚠️ limited | ❌ |
| Actor tracking | Thread-local, set anywhere | `whodunnit` (controller) | `current_user` (controller) | Custom |
| JWT / API friendly | ✅ | ⚠️ needs workaround | ⚠️ needs workaround | ⚠️ moderate |
| Background job support | ✅ set manually | ⚠️ manual wiring | ⚠️ manual wiring | ⚠️ manual |
| Chainable query DSL | ✅ | ❌ raw AR queries | ❌ raw AR queries | ❌ raw JSON ops |
| Rails required | ⚠️ ActiveRecord required | ✅ Rails required | ✅ Rails required | ✅ Rails required |
| Performance (large data) | ⚠️ unverified | ❌ heavy (full snapshots) | ⚠️ medium | ✅ optimized (JSONB) |
| Maturity | 🆕 new | ✅ battle-tested | ✅ battle-tested | ✅ stable |

**When to choose Auditron:**
- You are building an API-first app with JWT or token-based auth
- You need built-in log retention without writing your own cleanup
- You want a clean query DSL instead of raw ActiveRecord queries
- You set the actor from service objects or background jobs

**When to choose PaperTrail:**
- You need full version history and the ability to revert records
- You are on a traditional session-based Rails app
- You need a battle-tested, widely supported gem

**When to choose Logidze:**
- You are on PostgreSQL and need maximum query performance
- You want diff storage backed by native JSONB operations

---

## Compatibility

- Ruby `>= 3.0`
- ActiveRecord `>= 7.0`
- Rails `>= 7.0` (optional — works with ActiveRecord outside Rails)
- PostgreSQL, MySQL, SQLite

---

## Contributing

Bug reports and pull requests are welcome on GitHub.

---

## License

MIT