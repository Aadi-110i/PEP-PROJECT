-- schema/02_tables/audit_log.sql

-- Immutable log of configuration and rule changes.

CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID,
    action VARCHAR(20) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100) NOT NULL DEFAULT 'system',
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip_address INET,
    session_info JSONB,
    CONSTRAINT chk_audit_log_action CHECK (action IN ('INSERT', 'UPDATE', 'DELETE'))
);

COMMENT ON TABLE audit_log IS 'Append-only audit trail for changes to rules, blocklists, and clients.';
COMMENT ON COLUMN audit_log.entity_type IS 'Type of entity changed (e.g., rate_limit_rule, blocklist).';
