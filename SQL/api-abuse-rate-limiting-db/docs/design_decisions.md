# API Abuse & Rate Limiting Database: Design Decisions

## 1. Rate Limiting Algorithm Deep Dive
This database implements a **Token Bucket** algorithm for rate limiting. 
- **Math**: The bucket has a maximum capacity (`max_requests`). Tokens refill at a constant rate over `window_seconds`. 
- **Refill Formula**: `tokens_to_add = floor(elapsed_seconds * (max_requests / window_seconds))`. 
- **Why it's better**: Unlike a Fixed Window algorithm (which resets at the top of the minute, allowing a burst of 2x limits at the boundary), Token Bucket smoothly handles bursts while strictly enforcing the sustained rate. It only requires storing the `available_tokens` and `last_request_at` timestamp.

## 2. Concurrency Safety Analysis
In a highly concurrent API, multiple requests from the same client may arrive simultaneously. 
- **Atomicity**: The check uses `INSERT ... ON CONFLICT (client_id, endpoint_id) DO UPDATE ... RETURNING`. This relies on PostgreSQL's tuple-level locking.
- **Locking**: When the `UPDATE` evaluates, Postgres locks the row. The token math (adding refilled tokens, subtracting 1) happens atomically.
- **Why SELECT then UPDATE is wrong**: If we used `SELECT` to read tokens, did math in application code, and then `UPDATE`, two concurrent requests would read the same token count and both decrement it independently, causing a race condition and allowing excess traffic.

## 3. Partitioning Strategy
The `request_logs` table handles the most insert volume.
- **RANGE Partitioning**: It is partitioned by `created_at` on a monthly basis.
- **Partition Pruning**: Queries filtering by date (e.g., "last 7 days") will only scan the relevant monthly partitions, drastically reducing I/O.
- **Cleanup Strategy**: Historical data is pruned by simply running `DROP TABLE request_logs_YYYY_MM;`. This is an `O(1)` metadata operation, vastly outperforming `DELETE FROM ... WHERE ...` which bloats the WAL and requires aggressive VACUUMing.

## 4. Security Design
- **Key Hashing**: API keys are never stored in plaintext. We utilize the `pgcrypto` extension to hash keys. 
- **Prefix Pattern**: To allow efficient lookups without hashing every row, we store a `key_prefix` (e.g., first 8 chars). When authenticating, we `SELECT` rows matching the prefix, and then cryptographically verify the hash.

## 5. Performance Considerations
- **Indexes**: 
  - `rate_limit_windows` uses a composite Primary Key `(client_id, endpoint_id)` which provides an implicitly fast index for the UPSERTs.
  - `request_logs` partitions index `(client_id, created_at)` to rapidly serve abuse detection queries.
- **Estimated QPS**: On standard hardware, optimized Postgres UPSERTs can handle ~10,000 to 20,000 RPS. 

## 6. Scalability Limitations
- **What breaks at 100k RPS**: At extremely high scale, Postgres row-level locks on `rate_limit_windows` will cause CPU contention (lock waits). The WAL write volume for every API request will also saturate disk I/O.
- **How to fix it**: Offload rate-limiting state to **Redis** using Lua scripts. The Postgres database would then only serve as the durable Source of Truth for rules, configurations, and asynchronous log aggregation (via Kafka to clickhouse/TimescaleDB).

## 7. Future Improvements
- **Distributed Rate Limiting**: Implementing a Redis cluster for globally synchronized token buckets.
- **ML-Based Abuse Detection**: Exporting `request_logs` to a data warehouse to train models that detect anomalous behavioral patterns beyond static thresholds.
- **Webhooks**: Adding a listener via pg_notify to trigger HTTP webhooks when a client is added to the `blocklist`.
