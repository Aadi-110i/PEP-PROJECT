-- schema/02_tables/blocklist.sql

-- Supports both IP-level and client-level blocking.

CREATE TABLE blocklist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ip_address INET,
    client_id UUID,
    reason TEXT NOT NULL,
    blocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    blocked_by VARCHAR(100),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_blocklist_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    CONSTRAINT chk_blocklist_target CHECK (ip_address IS NOT NULL OR client_id IS NOT NULL)
);

COMMENT ON TABLE blocklist IS 'Active blocklist for IPs or clients due to abuse or manual intervention.';
COMMENT ON COLUMN blocklist.expires_at IS 'When the block automatically expires. NULL indicates a permanent block.';
