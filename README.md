# Auditron 🔍

**Know who changed what, when, and why — audit logging built for Rails APIs.**

[![Gem Version](https://badge.fury.io/rb/auditron.svg?icon=si%3Arubygems&icon_color=%23ce0303)](https://badge.fury.io/rb/auditron)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/spatelpatidar/auditron/blob/main/LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-3.0%2B-red)](https://www.ruby-lang.org/)
![GitHub Repo Views](https://gitviews.com/repo/spatelpatidar/auditron.svg)

> Built-in retention, flexible actor tracking, and a clean query DSL, for API-first Rails apps.

---

## The problem every API team hits

Your support team asks: *"Who changed this user's email last Tuesday?"*

You check the database. Nothing. You check the logs. Nothing useful. So you reach for an audit gem, and it assumes `current_user` lives in a controller, stores a full copy of the record on every change, and leaves you to write your own cleanup job.

That works for a classic session-based Rails app. It gets in your way when you're building with JWT, service objects, and background jobs.

**Auditron was designed for how modern Rails APIs are actually built:**

- 🔑 **JWT and service-layer friendly.** Set the actor anywhere, not just in controllers.
- 📦 **Diff-only storage.** Stores only what changed, not the whole object. Change one column on a 30-attribute model and you write one column.
- 🧹 **Built-in retention.** Configure once, run a job, and logs clean themselves up.
- 🔎 **Chainable query DSL.** Find exactly what you need without writing raw SQL.

> `paper_trail` writes a full snapshot on every change, so storage grows fast at scale. Both `paper_trail` and `audited` tie actor tracking to a controller's `current_user`, which doesn't exist in JWT or service-layer code. Neither ships with log retention.

---

## Who needs this?

- API-first Rails apps using JWT or token-based auth
- Apps under **GDPR, HIPAA, or SOC2** requirements that need audit trails
- Teams tired of audit tables bloating their database
- Anyone who needs to answer **"who changed this, when, and why?"**

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

## Install

Add it to your Gemfile:

```ruby
gem "auditron"
```

Then run:

```bash
bundle install
rails generate auditron:install
rails db:migrate
```

That's it. Now tell Auditron who's making changes (see [Controller setup](#controller-setup)) and add `auditable` to a model.

---

## Configuration

Create an initializer at `config/initializers/auditron.rb`:

```ruby
Auditron.configure do |config|
  # Fields to never log across all models
  config.ignored_fields = %i[updated_at created_at]

  # Include request IP in every log entry (default: false)
  config.store_ip = true

  # Auto-purge logs older than N days (default: nil, keep forever)
  # Call Auditron::Sweeper.purge! from a scheduled job
  config.retention_days = 90
end
```

> **Heads up:** don't set `current_actor` in the initializer. Instance variables like `@current_user` only exist during a request, so they aren't available there. See Controller setup below.

---

## Controller setup

Auditron needs to know who is making changes. Set the current actor in your controller after authentication. It works with **any auth system**.

Auditron stores the actor in a **thread-safe variable** and clears it automatically after every request, so it's safe for Puma and any threaded server.

### JWT (API apps)

```ruby
class ApplicationController < ActionController::API
  private

  def authenticate_account!
    token   = request.headers["Authorization"]&.split(" ")&.last
    payload = JsonAuthToken.decode(token)
    @current_user = Account.find_by(id: payload[:account_id])

    render json: { error: "Invalid token" }, status: :unauthorized and return unless @current_user

    # Set the actor. Auditron reads this on every model change.
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
# Set and clear manually. Auditron does not clear this automatically
# outside of a request cycle.
Auditron.current_actor = admin_user
account.update!(status: "suspended")
Auditron.current_actor = nil
```

> **Good to know:** on signup or any unauthenticated request, `actor_type` and `actor_id` will be `nil`. That's correct. The user doesn't exist yet, so there's no actor to record.

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

# Get the actor object directly from a log
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

No other major audit gem ships with built-in log retention. Configure it once and run it from any scheduled job:

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

## What a log entry looks like

Every `AuditLog` record contains:

| Field | Type | Description |
|-------|------|-------------|
| `auditable_type` | String | Model class name, e.g. `"Account"` |
| `auditable_id` | Integer | Record ID |
| `action` | String | `created`, `updated`, or `deleted` |
| `changed_fields` | JSON | Only changed fields, with before/after values |
| `actor_id` | Integer | ID of the actor who made the change |
| `actor_type` | String | Class name of the actor, e.g. `"Account"` |
| `ip_address` | String | Request IP (when `store_ip` is on) |
| `metadata` | JSON | Custom data attached via `audit_with` |
| `created_at` | DateTime | When the change happened |

### Example

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

An honest comparison. Every gem has strengths, so pick the right tool for your use case.

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

**Choose Auditron when:**
- You're building an API-first app with JWT or token-based auth
- You want built-in log retention without writing your own cleanup
- You'd rather have a clean query DSL than raw ActiveRecord queries
- You set the actor from service objects or background jobs

**Choose PaperTrail when:**
- You need full version history and the ability to revert records
- You're on a traditional session-based Rails app
- You want a battle-tested, widely supported gem

**Choose Logidze when:**
- You're on PostgreSQL and need maximum query performance
- You want diff storage backed by native JSONB operations

---

## Compatibility

- Ruby `>= 3.0`
- ActiveRecord `>= 7.0`
- Rails `>= 7.0` (optional, works with ActiveRecord outside Rails)
- PostgreSQL, MySQL, SQLite

---

## Also by the same author: Respondo 🎯

Building a Rails API? Auditron pairs nicely with [**Respondo**](https://github.com/spatelpatidar/respondo), which gives every JSON response the same shape (`success`, `message`, `data`, `meta`) with one-line helpers like `render_ok` and `render_created`.

Audit your changes with Auditron, standardize your responses with Respondo.

---

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/spatelpatidar/auditron).

```bash
git clone https://github.com/spatelpatidar/auditron
cd auditron
bundle install
bundle exec rspec
```

Found a bug or have a feature idea? [Open an issue →](https://github.com/spatelpatidar/auditron/issues)

---

## License

Released under the [MIT License](https://github.com/spatelpatidar/auditron/blob/main/LICENSE).

---

If Auditron saved you from a "who changed this?" mystery, give it a ⭐ on [GitHub](https://github.com/spatelpatidar/auditron). It helps other developers find it.