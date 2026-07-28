-- clients.sql

CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    plan_id UUID NOT NULL REFERENCES plans(id) ON DELETE RESTRICT,
    is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
    blocked_at TIMESTAMPTZ,
    blocked_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_blocked_at_matches_is_blocked CHECK ((NOT is_blocked AND blocked_at IS NULL) OR (is_blocked AND blocked_at IS NOT NULL))
);

COMMENT ON TABLE clients IS 'Stores information about API clients (users/organizations) accessing the system.';
COMMENT ON COLUMN clients.id IS 'Unique identifier for the client.';
COMMENT ON COLUMN clients.name IS 'Name of the client organization or user.';
COMMENT ON COLUMN clients.email IS 'Contact email address for the client.';
COMMENT ON COLUMN clients.plan_id IS 'Reference to the plan the client is subscribed to.';
COMMENT ON COLUMN clients.is_blocked IS 'Indicates if the client is currently blocked from using the API.';
COMMENT ON COLUMN clients.blocked_at IS 'Timestamp when the client was blocked. Must be null if not blocked.';
COMMENT ON COLUMN clients.blocked_reason IS 'Reason for blocking the client (e.g., abuse detection, payment failure).';
COMMENT ON COLUMN clients.created_at IS 'Timestamp when the client was created.';
COMMENT ON COLUMN clients.updated_at IS 'Timestamp when the client was last updated.';
