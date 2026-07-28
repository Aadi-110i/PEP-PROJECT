-- Indexes for request_logs
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_request_logs_client_endpoint_time 
ON request_logs (client_id, endpoint_id, created_at DESC);
-- Purpose: Speeds up querying recent logs for a specific client and endpoint.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_request_logs_client_errors 
ON request_logs (client_id, created_at) WHERE status_code >= 400;
-- Purpose: Quickly find error logs for a specific client, useful for abuse detection.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_request_logs_ip_address 
ON request_logs (ip_address);
-- Purpose: Lookup logs by IP address.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_request_logs_created_at 
ON request_logs (created_at);
-- Purpose: Time-based filtering of logs.

-- Indexes for api_keys
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_api_keys_key_hash 
ON api_keys (key_hash);
-- Purpose: Ensure fast uniqueness checks on key hashes.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_api_keys_client_id 
ON api_keys (client_id);
-- Purpose: Lookup all keys for a given client.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_api_keys_active_client 
ON api_keys (client_id) WHERE revoked_at IS NULL;
-- Purpose: Quickly find the active keys for a client.

-- Indexes for rate_limit_windows
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_rate_limit_windows_covering 
ON rate_limit_windows (client_id, endpoint_id) INCLUDE (tokens_remaining, last_request_at);
-- Purpose: Covering index to fetch remaining tokens and last request time efficiently during rate limit checks.

-- Indexes for abuse_flags
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_abuse_flags_client_detected 
ON abuse_flags (client_id, detected_at DESC);
-- Purpose: Fetch recent abuse flags for a client.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_abuse_flags_open 
ON abuse_flags (client_id) WHERE resolved_at IS NULL;
-- Purpose: Quickly identify clients with unresolved/open abuse flags.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_abuse_flags_severity 
ON abuse_flags (severity);
-- Purpose: Filter abuse flags by severity level.

-- Indexes for blocklist
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_blocklist_permanent_active_ip 
ON blocklist (ip_address) WHERE is_active = true AND expires_at IS NULL;
-- Purpose: Fast lookup of permanently blocked IP addresses.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_blocklist_active_client 
ON blocklist (client_id) WHERE is_active = true;
-- Purpose: Fast lookup of active blocks for clients.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_blocklist_expires_at 
ON blocklist (expires_at);
-- Purpose: Efficiently query expired blocks for cleanup jobs.

-- Indexes for rate_limit_rules
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_rate_limit_rules_client_endpoint 
ON rate_limit_rules (client_id, endpoint_id);
-- Purpose: Lookup rate limit rules for a specific client and endpoint.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_rate_limit_rules_priority 
ON rate_limit_rules (priority DESC);
-- Purpose: Order rate limit rules by priority.

-- Indexes for audit_log
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_entity 
ON audit_log (entity_type, entity_id);
-- Purpose: Fetch audit logs for specific entities.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_changed_at 
ON audit_log (changed_at DESC);
-- Purpose: Time-based filtering of audit logs.
