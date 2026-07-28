-- plans.sql

CREATE TABLE IF NOT EXISTS plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    requests_per_window INT NOT NULL CHECK (requests_per_window > 0),
    window_seconds INT NOT NULL CHECK (window_seconds > 0),
    burst_allowance INT NOT NULL DEFAULT 0 CHECK (burst_allowance >= 0),
    max_concurrent_requests INT DEFAULT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE plans IS 'Defines the available API usage plans and their baseline rate limit configurations.';
COMMENT ON COLUMN plans.id IS 'Unique identifier for the plan.';
COMMENT ON COLUMN plans.name IS 'Unique name of the plan (e.g., Basic, Pro, Enterprise).';
COMMENT ON COLUMN plans.requests_per_window IS 'Baseline number of allowed requests per time window.';
COMMENT ON COLUMN plans.window_seconds IS 'Duration of the time window in seconds.';
COMMENT ON COLUMN plans.burst_allowance IS 'Additional burst capacity allowed beyond the baseline rate limit.';
COMMENT ON COLUMN plans.max_concurrent_requests IS 'Maximum number of concurrent requests allowed for clients on this plan. NULL means unlimited.';
COMMENT ON COLUMN plans.is_active IS 'Indicates if the plan is currently available for new clients.';
COMMENT ON COLUMN plans.created_at IS 'Timestamp when the plan was created.';
COMMENT ON COLUMN plans.updated_at IS 'Timestamp when the plan was last updated.';
