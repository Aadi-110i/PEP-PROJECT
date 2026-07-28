-- api_keys.sql

CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    key_hash VARCHAR(64) NOT NULL UNIQUE,
    key_prefix VARCHAR(8) NOT NULL,
    label VARCHAR(100),
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    CONSTRAINT check_revoked_at_past CHECK (revoked_at <= now() OR revoked_at IS NULL)
);

COMMENT ON TABLE api_keys IS 'Stores API keys assigned to clients for authentication. Only stores one-way hashes for security.';
COMMENT ON COLUMN api_keys.id IS 'Unique identifier for the API key record.';
COMMENT ON COLUMN api_keys.client_id IS 'Reference to the client owning this key.';
COMMENT ON COLUMN api_keys.key_hash IS 'SHA-256 hash of the API key. The plaintext key is never stored.';
COMMENT ON COLUMN api_keys.key_prefix IS 'First 8 characters of the plaintext key, used for UI identification and display.';
COMMENT ON COLUMN api_keys.label IS 'User-provided label for the key (e.g., "Production Key", "Staging Key").';
COMMENT ON COLUMN api_keys.last_used_at IS 'Timestamp when the key was last used for authentication.';
COMMENT ON COLUMN api_keys.created_at IS 'Timestamp when the key was created.';
COMMENT ON COLUMN api_keys.updated_at IS 'Timestamp when the key was last updated.';
COMMENT ON COLUMN api_keys.revoked_at IS 'Timestamp when the key was revoked. Must be in the past or null.';
COMMENT ON COLUMN api_keys.expires_at IS 'Timestamp when the key is scheduled to expire.';
