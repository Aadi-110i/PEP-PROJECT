# API Abuse & Rate Limiting Database

![PostgreSQL 15+](https://img.shields.io/badge/PostgreSQL-15+-336791.svg?style=flat-square&logo=postgresql)
![License MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)
![SQL-only](https://img.shields.io/badge/Implementation-SQL--only-orange.svg?style=flat-square)

## Overview

The API Abuse & Rate Limiting Database is a production-grade, SQL-only PostgreSQL implementation of an API gateway rate limiting and abuse detection system. Designed as a robust backend component, this project manages high-throughput API access control entirely within the database layer.

This is a portfolio project demonstrating advanced PostgreSQL features, including atomic operations, table partitioning, triggers, custom functions, and complex views. By avoiding external dependencies like Redis for rate limiting, this solution provides strong consistency and transactional guarantees while simplifying the infrastructure stack.

The system is designed to handle high-volume API traffic gracefully. It features a robust token bucket algorithm that prevents race conditions during high concurrency, a partitioned logging architecture to sustain heavy write workloads without degradation, and automated abuse detection mechanisms that temporarily quarantine bad actors.

## Features

- **Token bucket rate limiting** — Implemented natively in SQL with atomic `INSERT ... ON CONFLICT DO UPDATE ... RETURNING` for concurrency safety. The entire check-and-decrement is one statement; no two concurrent callers can both succeed past an exhausted bucket.
- **Partitioned `request_logs` table** — Uses `RANGE` partitioning by month for high-volume write performance, partition pruning on queries, and efficient archival via `DROP TABLE` on old partitions.
- **Automatic abuse detection via triggers** — `trg_auto_flag_abuse` fires after every insert into `request_logs`, checking rolling-window counts and error ratios in real time.
- **Blocklist with TTL (temporary bans)** — Supports both IP-level and client-level blocks with optional `expires_at` for automatic expiry.
- **Priority-based rule override system** — Per-client+endpoint rules override per-client rules, which override per-endpoint rules, which override the global rule. Higher `priority` wins.
- **API key management** — Credentials stored as SHA-256 hashes (`key_hash`) with a display prefix (`key_prefix`). Plaintext keys are never persisted.
- **Operational views for monitoring** — `v_active_abusers`, `v_top_endpoints_by_traffic`, `v_client_usage_summary` ready for a dashboard.
- **Audit log** — Append-only record of every rule and config change with old/new JSONB values.
- **Realistic seed data** — Three abuser profiles (spambot, scraper, brute-forcer) generating enough traffic to demo the detection pipeline immediately after seeding.
- **Full test suite in pure SQL** — 7 rate-limit tests and full abuse-detection coverage, with pass/fail reporting via `RAISE NOTICE`.

## Architecture

```text
                         ┌─────────────────┐
                         │   API Request   │
                         └────────┬────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │   check_rate_limit()    │  ← resolves highest-priority rule
                    └────────────┬────────────┘
                                 │  atomic INSERT ... ON CONFLICT DO UPDATE
                                 ▼
              ┌──────────────────────────────────┐
              │       rate_limit_windows          │  ← single hot row per (client, endpoint)
              └──────────────────────────────────┘
                    allowed ◄──────────► denied
                       │                    │
                       ▼                    ▼
              ┌────────────────┐   retry_after_seconds
              │  request_logs  │   (partitioned by month)
              └───────┬────────┘
                      │  AFTER INSERT trigger
                      ▼
              ┌───────────────┐
              │  abuse_flags  │  ← auto-flagged on volume/error spikes
              └───────────────┘

  Maintenance jobs (schedule via pg_cron or cron):
    cleanup_old_logs(90)     — weekly, drops old partitions
    refresh_abuse_stats()    — every 5 min, refreshes materialized view
    create_monthly_partition() — monthly, pre-creates next partition
```

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) & Docker Compose
- [`psql`](https://www.postgresql.org/download/) (PostgreSQL 15+ client)

## Quick Start

### 1. Start PostgreSQL with Docker

Create a `docker-compose.yml` in the project root:

```yaml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: rate_limit_db
    environment:
      POSTGRES_DB: rate_limit_db
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secret
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin -d rate_limit_db"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

Then start it:

```bash
docker-compose up -d
# Wait for the health check to pass
docker-compose ps
```

### 2. Connect

```bash
psql -h localhost -U admin -d rate_limit_db
# Password: secret
```

### 3. Run Scripts In Order

Execute the following in `psql` (or use the one-liners below):

```sql
\i schema/01_extensions.sql
\i schema/02_tables/plans.sql
\i schema/02_tables/clients.sql
\i schema/02_tables/api_keys.sql
\i schema/02_tables/endpoints.sql
\i schema/02_tables/rate_limit_rules.sql
\i schema/02_tables/request_logs.sql
\i schema/02_tables/rate_limit_windows.sql
\i schema/02_tables/abuse_flags.sql
\i schema/02_tables/blocklist.sql
\i schema/02_tables/audit_log.sql
\i schema/03_indexes.sql
\i schema/04_constraints.sql
\i schema/05_partitions.sql
\i functions/check_rate_limit.sql
\i functions/flag_abuse.sql
\i functions/cleanup_old_logs.sql
\i functions/refresh_abuse_stats.sql
\i triggers/trg_auto_flag_abuse.sql
\i triggers/trg_update_last_seen.sql
\i views/v_active_abusers.sql
\i views/v_top_endpoints_by_traffic.sql
\i views/v_client_usage_summary.sql
\i seed/seed_plans.sql
\i seed/seed_endpoints.sql
\i seed/seed_clients.sql
```

**Bash one-liner (Linux / macOS / Git Bash):**

```bash
export PGPASSWORD=secret
for f in \
  schema/01_extensions.sql \
  schema/02_tables/plans.sql \
  schema/02_tables/clients.sql \
  schema/02_tables/api_keys.sql \
  schema/02_tables/endpoints.sql \
  schema/02_tables/rate_limit_rules.sql \
  schema/02_tables/request_logs.sql \
  schema/02_tables/rate_limit_windows.sql \
  schema/02_tables/abuse_flags.sql \
  schema/02_tables/blocklist.sql \
  schema/02_tables/audit_log.sql \
  schema/03_indexes.sql \
  schema/04_constraints.sql \
  schema/05_partitions.sql \
  functions/check_rate_limit.sql \
  functions/flag_abuse.sql \
  functions/cleanup_old_logs.sql \
  functions/refresh_abuse_stats.sql \
  triggers/trg_auto_flag_abuse.sql \
  triggers/trg_update_last_seen.sql \
  views/v_active_abusers.sql \
  views/v_top_endpoints_by_traffic.sql \
  views/v_client_usage_summary.sql \
  seed/seed_plans.sql \
  seed/seed_endpoints.sql \
  seed/seed_clients.sql; do
    echo "Running $f..." && psql -h localhost -U admin -d rate_limit_db -f "$f"
done
```

**PowerShell one-liner (Windows):**

```powershell
$env:PGPASSWORD = "secret"
$files = @(
  "schema/01_extensions.sql",
  "schema/02_tables/plans.sql", "schema/02_tables/clients.sql",
  "schema/02_tables/api_keys.sql", "schema/02_tables/endpoints.sql",
  "schema/02_tables/rate_limit_rules.sql", "schema/02_tables/request_logs.sql",
  "schema/02_tables/rate_limit_windows.sql", "schema/02_tables/abuse_flags.sql",
  "schema/02_tables/blocklist.sql", "schema/02_tables/audit_log.sql",
  "schema/03_indexes.sql", "schema/04_constraints.sql", "schema/05_partitions.sql",
  "functions/check_rate_limit.sql", "functions/flag_abuse.sql",
  "functions/cleanup_old_logs.sql", "functions/refresh_abuse_stats.sql",
  "triggers/trg_auto_flag_abuse.sql", "triggers/trg_update_last_seen.sql",
  "views/v_active_abusers.sql", "views/v_top_endpoints_by_traffic.sql",
  "views/v_client_usage_summary.sql",
  "seed/seed_plans.sql", "seed/seed_endpoints.sql", "seed/seed_clients.sql"
)
foreach ($f in $files) {
  Write-Host "Running $f..." -ForegroundColor Cyan
  psql -h localhost -U admin -d rate_limit_db -f $f
}
```

### 4. Run Tests

```bash
psql -h localhost -U admin -d rate_limit_db -f tests/test_rate_limit_function.sql
psql -h localhost -U admin -d rate_limit_db -f tests/test_abuse_detection.sql
```

Check the `NOTICE` output — you should see `7/7 tests passed` for rate limiting and all abuse detection assertions green.

## Usage Examples

**1. Check if a request is allowed (token bucket):**
```sql
SELECT allowed, tokens_remaining, retry_after_seconds, reason
FROM check_rate_limit(
  '550e8400-e29b-41d4-a716-446655440000',  -- client_id
  '123e4567-e89b-12d3-a456-426614174000'   -- endpoint_id
);
```

**2. View current active abusers:**
```sql
SELECT client_name, email, plan_name, open_flag_count,
       highest_severity, total_requests_last_24h, error_rate_last_24h
FROM v_active_abusers
LIMIT 20;
```

**3. Manually block an IP for 24 hours:**
```sql
INSERT INTO blocklist (ip_address, reason, expires_at, blocked_by)
VALUES (
  '203.0.113.42',
  'Observed scanning behaviour across multiple endpoints',
  now() + interval '24 hours',
  'ops-team'
);
```

**4. Inspect top endpoints by traffic:**
```sql
SELECT path, method, total_requests, unique_clients,
       p95_response_time_ms, error_rate, rate_limited_count
FROM v_top_endpoints_by_traffic
LIMIT 10;
```

**5. Manually raise an abuse flag:**
```sql
SELECT flag_abuse(
  '550e8400-e29b-41d4-a716-446655440000',
  '123e4567-e89b-12d3-a456-426614174000',
  'Unusual spike in DELETE requests',
  'high'
);
```

## Maintenance

| Task | Frequency | Command |
|---|---|---|
| Drop old log partitions | Weekly | `SELECT * FROM cleanup_old_logs(90);` |
| Refresh abuse stats MV | Every 5 min | `SELECT refresh_abuse_stats();` |
| Pre-create next partition | Monthly | `SELECT create_monthly_partition(date_trunc('month', now() + interval '1 month')::DATE);` |

**pg_cron example (if `pg_cron` extension is installed):**
```sql
SELECT cron.schedule('refresh-abuse-stats', '*/5 * * * *', 'SELECT refresh_abuse_stats()');
SELECT cron.schedule('cleanup-old-logs',    '0 3 * * 0',   'SELECT cleanup_old_logs(90)');
```

## Project Structure

```text
api-abuse-rate-limiting-db/
├── README.md
├── docker-compose.yml
├── schema/
│   ├── 01_extensions.sql          -- uuid-ossp, pgcrypto, btree_gin, pg_trgm
│   ├── 02_tables/
│   │   ├── plans.sql              -- subscription tiers
│   │   ├── clients.sql            -- API consumers
│   │   ├── api_keys.sql           -- SHA-256 hashed credentials
│   │   ├── endpoints.sql          -- route registry with defaults
│   │   ├── rate_limit_rules.sql   -- override rules with priority
│   │   ├── request_logs.sql       -- partitioned write-heavy log
│   │   ├── rate_limit_windows.sql -- hot state for token bucket
│   │   ├── abuse_flags.sql        -- detected violations
│   │   ├── blocklist.sql          -- IP + client-level bans
│   │   └── audit_log.sql          -- append-only change history
│   ├── 03_indexes.sql             -- all composite & partial indexes
│   ├── 04_constraints.sql         -- cross-table constraints + updated_at triggers
│   └── 05_partitions.sql          -- monthly partitions + create_monthly_partition()
├── functions/
│   ├── check_rate_limit.sql       -- atomic token bucket check
│   ├── flag_abuse.sql             -- idempotent abuse flagging
│   ├── cleanup_old_logs.sql       -- partition archival + stale row cleanup
│   └── refresh_abuse_stats.sql    -- materialized view refresh + escalation
├── triggers/
│   ├── trg_auto_flag_abuse.sql    -- auto-flag on volume/error spikes
│   └── trg_update_last_seen.sql   -- keeps api_keys.last_used_at fresh
├── views/
│   ├── v_active_abusers.sql       -- real-time abuser dashboard
│   ├── v_top_endpoints_by_traffic.sql
│   └── v_client_usage_summary.sql
├── seed/
│   ├── seed_plans.sql
│   ├── seed_endpoints.sql
│   └── seed_clients.sql           -- includes abuser traffic via generate_series
├── tests/
│   ├── test_rate_limit_function.sql  -- 7 boundary & concurrency tests
│   └── test_abuse_detection.sql      -- trigger, view, and function tests
└── docs/
    ├── ERD.md                     -- Mermaid entity-relationship diagram
    └── design_decisions.md        -- deep dives on algorithm, concurrency, partitioning
```

## Contributing

Contributions are welcome!

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Ensure all tests pass against a fresh Postgres 15 instance
4. Commit your changes: `git commit -m 'feat: add my feature'`
5. Push to the branch: `git push origin feature/my-feature`
6. Open a Pull Request with a clear description of what changed and why

## License

MIT — see [LICENSE](LICENSE) for details.

## Python Analytics Phase

In addition to the SQL-native implementation, this project features a Python analytics layer to extract actionable business insights from the logs.

### Features
- **Data Cleaning:** Extracts data from the DB to Pandas DataFrames and processes datetime features, categorical standardizations, and burst detection.
- **EDA & KPIs:** Automatically calculates violation rates, block rates, and tracks top offenders via `eda.py` and `kpi_analysis.py`.
- **Visualizations:** Generates automated trend charts and breakdown distributions (`visualization.py`).

### How to Run
1. Navigate to the project root and install requirements:
   \\\ash
   pip install -r requirements.txt
   \\\
2. Configure credentials:
   Copy `.env.example` to `.env` and fill in your DB connection details.
3. Run the pipeline in order:
   \\\ash
   python Python/db_connection.py
   python Python/data_cleaning.py
   python Python/eda.py
   python Python/kpi_analysis.py
   python Python/visualization.py
   \\\
4. Output results will be placed in `Data/cleaned/`, `Output/Charts/`, and `Output/Results/`.

### Insights Report
Check out the [Project Report](Reports/project_report.md) for detailed observations, business impact analysis, and technical recommendations.
