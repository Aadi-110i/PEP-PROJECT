-- endpoints.sql

CREATE TABLE IF NOT EXISTS endpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    path VARCHAR(500) NOT NULL,
    method VARCHAR(10) NOT NULL CHECK (method IN ('GET','POST','PUT','PATCH','DELETE','OPTIONS','HEAD')),
    default_limit INT NOT NULL DEFAULT 100,
    default_window_seconds INT NOT NULL DEFAULT 60,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(path, method)
);

COMMENT ON TABLE endpoints IS 'Registry of API endpoints and their default rate limiting configurations.';
COMMENT ON COLUMN endpoints.id IS 'Unique identifier for the endpoint.';
COMMENT ON COLUMN endpoints.path IS 'The URL path of the endpoint (e.g., /api/v1/users).';
COMMENT ON COLUMN endpoints.method IS 'HTTP method allowed for the endpoint.';
COMMENT ON COLUMN endpoints.default_limit IS 'Default maximum number of requests allowed within the default window.';
COMMENT ON COLUMN endpoints.default_window_seconds IS 'Default duration of the rate limit window in seconds.';
COMMENT ON COLUMN endpoints.description IS 'Optional description of the endpoint''s purpose.';
COMMENT ON COLUMN endpoints.is_active IS 'Indicates if the endpoint is currently active and reachable.';
COMMENT ON COLUMN endpoints.created_at IS 'Timestamp when the endpoint was created.';
COMMENT ON COLUMN endpoints.updated_at IS 'Timestamp when the endpoint was last updated.';
