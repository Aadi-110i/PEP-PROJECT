-- schema/02_tables/rate_limit_windows.sql

-- This table holds the hot state for rate-limit decisions (e.g., token bucket or fixed window algorithms).

CREATE TABLE rate_limit_windows (
    client_id UUID NOT NULL,
    endpoint_id UUID NOT NULL,
    window_start TIMESTAMPTZ NOT NULL,
    window_end TIMESTAMPTZ NOT NULL,
    request_count INT NOT NULL DEFAULT 0,
    tokens_remaining INT NOT NULL DEFAULT 0,
    last_request_at TIMESTAMPTZ,
    algorithm VARCHAR(20) NOT NULL,
    PRIMARY KEY (client_id, endpoint_id),
    CONSTRAINT fk_rl_windows_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    CONSTRAINT fk_rl_windows_endpoint FOREIGN KEY (endpoint_id) REFERENCES endpoints(id) ON DELETE CASCADE,
    CONSTRAINT chk_tokens_remaining CHECK (tokens_remaining >= 0)
);

COMMENT ON TABLE rate_limit_windows IS 'Maintains hot state for atomic rate-limit checks and token bucket tracking.';
