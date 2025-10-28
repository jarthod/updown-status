# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a customized Staytus status page application used to monitor updown.io infrastructure. It receives health check pings from distributed monitoring daemons and Sidekiq workers, automatically updates service statuses, and sends email alerts when issues are detected.

**Key customization**: The `/ping` and `/sidekiq` endpoints accept HTTP requests from whitelisted IPs to track the health of distributed monitoring infrastructure. A background thread continuously checks for stale pings and triggers alerts/service status updates.

## Development Commands

### Running Locally
```sh
# Development server with local SMTP (requires mailcatcher)
STAYTUS_SMTP_HOSTNAME=localhost STAYTUS_SMTP_PORT=1025 rails s

# Console
bin/rails c
```

### Testing
```sh
# Run all tests
rake

# Run specific test file
ruby -I test test/integration/updown_test.rb

# Run specific test case
ruby -I test test/integration/updown_test.rb -n test_register_daemon_check_and_returns_200
```

### Database
```sh
# Initial setup
bundle exec rake staytus:build staytus:install

# Run migrations (after pulling updates)
bundle exec rake staytus:upgrade

# Import production database from Render (dev only)
scp -s srv-cklr2o2v7m0s73al2020@ssh.frankfurt.render.com:/var/data/staytus_prod.sqlite3 db/staytus_dev.sqlite3
```

### Deployment
```sh
# Deploy to Render
git push
```

### Testing Monitoring Endpoints Locally
```sh
# Test daemon ping endpoint
curl -iH 'X-Forwarded-For: 91.121.222.175' localhost:8787/ping

# Test sidekiq health endpoint
curl -iH 'X-Forwarded-For: 91.121.222.175' -d 'queues[default]=5000&queues[mailers]=0&env=production' localhost:8787/sidekiq
```

## Architecture

### Core Models
- **Site**: Global configuration (title, domain, email settings, time zone)
- **Service**: Monitored components (Web, API, daemons per location, etc.)
- **ServiceStatus**: Status types (operational, degraded, partial-outage, major-outage, maintenance)
- **ServiceGroup**: Optional grouping for services
- **Issue**: Incident tracking with state machine (investigating → identified → monitoring → resolved)
- **IssueUpdate**: Timeline updates for issues
- **Maintenance**: Scheduled maintenance windows
- **Subscriber**: Email subscription management

### Custom Monitoring System (`config/initializers/updown.rb`)

**Updown module** maintains in-memory state for monitoring:
- `DAEMONS`: Hash mapping daemon IPs to location names (lan, mia, bhs, rbx, fra, hel, sin, tok, syd)
- `WORKERS`: Combined hash of web servers and daemons that run Sidekiq
- `last_checks`: Tracks ping timestamps per daemon (capped at 20)
- `last_sidekiq_ping`: Tracks Sidekiq health check timestamps (capped at 20)
- `status`: Current up/down state per daemon and global
- `sidekiq_status`: Current up/down state per worker
- `disabled_locations`: Manually disabled monitoring locations

**Background thread** (`Thread.new` at end of initializer):
- Runs every 60 seconds
- Calls `check_status`: Detects stale daemons (>1h) and workers (>5m), attempts VM reboots via Vultr API, sends email alerts
- Calls `check_postmark`: Monitors Postmark email service status via their API
- Calls `check_web_urls`: Monitors updown.io web, API, and custom status page URLs
- Calls `update_services`: Updates Service records based on current state

**Endpoints** (`app/controllers/updown_controller.rb`):
- `GET /ping`: Accepts requests from whitelisted daemon IPs, records check time, marks daemon as up if was down
- `POST /sidekiq`: Accepts queue size data from whitelisted worker IPs, validates queue health thresholds (default < 5000, mailers < 10, low < 10000)

**Service permalink convention**: Daemons create services named `daemon-{location}` (e.g., `daemon-rbx`, `daemon-syd`)

### Email Notifications
- Background jobs via `delayed_job_active_record`
- SMTP configuration via environment variables (see `config/environment.example.yml`)
- Templates managed via admin panel
- Alert emails sent to `bigbourin@gmail.com` (configured in `Updown.notify`)

### Authentication & Security
- Admin authentication via Authie gem (session management)
- IP whitelisting for monitoring endpoints
- Trusted proxy configuration for CloudFlare/Render
- Rack::Attack for rate limiting
- InvisibleCaptcha for spam protection

### Theme System
- Themes in `content/themes/` directory
- Default theme: `content/themes/default`
- Configured via `STAYTUS_THEME` environment variable
- Custom themes should not modify default theme (overridden on upgrade)

## Database

SQLite in production (Render deployment), configured for test/dev via `config/database.yml`. Original Staytus used MySQL but this instance has been adapted for SQLite.

Note: The application can survive temporary database outages for the monitoring endpoints (`/ping` and `/sidekiq`) because critical in-memory state is updated before database operations.

## Important Configuration Files

- `config/initializers/updown.rb`: Custom monitoring logic, background checks, IP whitelists
- `config/environment.yml`: SMTP, SSL, theme settings (not committed, see `environment.example.yml`)
- `config/database.yml`: Database config (not committed, see `database.example.yml`)
- `Procfile`: Process definitions for web server (puma)
- `.ruby-version`: Ruby 3.3.5

## Admin Access

Default credentials (first-time setup):
- URL: `/admin`
- Email: `admin@example.com`
- Password: `password`

**Change immediately after setup via Settings → Users**
