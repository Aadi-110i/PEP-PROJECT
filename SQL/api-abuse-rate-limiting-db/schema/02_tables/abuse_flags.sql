-- schema/02_tables/abuse_flags.sql

-- Tracks detected instances of API abuse or anomalies.

CREATE TABLE abuse_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    endpoint_id UUID,
    reason TEXT NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'medium',
    details JSONB DEFAULT '{}',
    detected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ,
    resolved_by VARCHAR(100),
    resolution_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_abuse_flags_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    CONSTRAINT fk_abuse_flags_endpoint FOREIGN KEY (endpoint_id) REFERENCES endpoints(id) ON DELETE SET NULL,
    CONSTRAINT chk_abuse_flags_severity CHECK (severity IN ('low', 'medium', 'high', 'critical'))
);

COMMENT ON TABLE abuse_flags IS 'Records instances of detected API abuse, rate limit violations, or anomalous behavior.';
COMMENT ON COLUMN abuse_flags.severity IS 'Severity of the abuse: low, medium, high, or critical.';
