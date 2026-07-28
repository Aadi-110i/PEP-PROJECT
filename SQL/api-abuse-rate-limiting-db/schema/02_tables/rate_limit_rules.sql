-- rate_limit_rules.sql

CREATE TABLE IF NOT EXISTS rate_limit_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    endpoint_id UUID REFERENCES endpoints(id) ON DELETE CASCADE,
    limit_requests INT NOT NULL CHECK (limit_requests > 0),
    window_seconds INT NOT NULL CHECK (window_seconds > 0),
    algorithm VARCHAR(20) NOT NULL DEFAULT 'token_bucket' CHECK (algorithm IN ('fixed_window','sliding_window','token_bucket')),
    burst_allowance INT NOT NULL DEFAULT 0,
    priority INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by VARCHAR(100)
);

COMMENT ON TABLE rate_limit_rules IS 'Defines granular rate limiting rules. Rule precedence: client+endpoint > client-only > endpoint-only > global.';
COMMENT ON COLUMN rate_limit_rules.id IS 'Unique identifier for the rate limit rule.';
COMMENT ON COLUMN rate_limit_rules.client_id IS 'Specific client the rule applies to. If NULL, applies to all clients.';
COMMENT ON COLUMN rate_limit_rules.endpoint_id IS 'Specific endpoint the rule applies to. If NULL, applies to all endpoints.';
COMMENT ON COLUMN rate_limit_rules.limit_requests IS 'Maximum number of requests allowed within the specified window.';
COMMENT ON COLUMN rate_limit_rules.window_seconds IS 'Duration of the rate limit window in seconds.';
COMMENT ON COLUMN rate_limit_rules.algorithm IS 'Rate limiting algorithm to employ for this rule (fixed_window, sliding_window, or token_bucket).';
COMMENT ON COLUMN rate_limit_rules.burst_allowance IS 'Additional burst capacity allowed beyond the limit.';
COMMENT ON COLUMN rate_limit_rules.priority IS 'Priority of the rule. Higher number indicates higher priority when resolving conflicts.';
COMMENT ON COLUMN rate_limit_rules.is_active IS 'Indicates if the rule is currently enforced.';
COMMENT ON COLUMN rate_limit_rules.created_at IS 'Timestamp when the rule was created.';
COMMENT ON COLUMN rate_limit_rules.updated_at IS 'Timestamp when the rule was last updated.';
COMMENT ON COLUMN rate_limit_rules.created_by IS 'Audit field indicating who created the rule.';
