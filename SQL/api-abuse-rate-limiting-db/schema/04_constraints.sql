-- Constraints

-- 1. UNIQUE constraint on (client_id, endpoint_id) for rate_limit_windows
ALTER TABLE rate_limit_windows 
ADD CONSTRAINT uq_rate_limit_windows_client_endpoint UNIQUE (client_id, endpoint_id);

-- 2. Partial unique constraint on rate_limit_rules
-- Using a unique index for partial unique constraints in PostgreSQL
CREATE UNIQUE INDEX IF NOT EXISTS uq_rate_limit_rules_active 
ON rate_limit_rules (client_id, endpoint_id, algorithm) WHERE is_active = true;

-- 3. abuse_flags.resolved_at >= abuse_flags.detected_at
ALTER TABLE abuse_flags 
ADD CONSTRAINT chk_abuse_flags_dates CHECK (resolved_at IS NULL OR resolved_at >= detected_at);

-- 4. blocklist.expires_at > blocklist.blocked_at
ALTER TABLE blocklist 
ADD CONSTRAINT chk_blocklist_dates CHECK (expires_at IS NULL OR expires_at > blocked_at);

-- 5. rate_limit_windows.window_end > rate_limit_windows.window_start
ALTER TABLE rate_limit_windows 
ADD CONSTRAINT chk_rate_limit_windows_dates CHECK (window_end > window_start);

-- 6. clients.blocked_at must be set when is_blocked = true
ALTER TABLE clients 
ADD CONSTRAINT chk_clients_blocked_at CHECK ((is_blocked = false) OR (is_blocked = true AND blocked_at IS NOT NULL));

-- Trigger Function: set_updated_at()
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER trg_plans_updated_at
BEFORE UPDATE ON plans
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_clients_updated_at
BEFORE UPDATE ON clients
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_api_keys_updated_at
BEFORE UPDATE ON api_keys
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_endpoints_updated_at
BEFORE UPDATE ON endpoints
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_rate_limit_rules_updated_at
BEFORE UPDATE ON rate_limit_rules
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_rate_limit_windows_updated_at
BEFORE UPDATE ON rate_limit_windows
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_abuse_flags_updated_at
BEFORE UPDATE ON abuse_flags
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_blocklist_updated_at
BEFORE UPDATE ON blocklist
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
