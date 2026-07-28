-- schema/02_tables/request_logs.sql

-- Request logs track every API request for analysis and billing.
-- Using BIGSERIAL instead of UUID for ID to improve insertion performance
-- and reduce index size in high-volume environments.
-- The PRIMARY KEY must include the partition key (created_at).

CREATE TABLE request_logs (
    id BIGSERIAL,
    client_id UUID NOT NULL,
    endpoint_id UUID NOT NULL,
    api_key_id UUID,
    ip_address INET NOT NULL,
    user_agent TEXT,
    status_code SMALLINT NOT NULL,
    response_time_ms INT,
    request_size_bytes INT,
    bytes_sent INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id, created_at),
    CONSTRAINT fk_request_logs_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
    CONSTRAINT fk_request_logs_endpoint FOREIGN KEY (endpoint_id) REFERENCES endpoints(id) ON DELETE SET NULL,
    CONSTRAINT fk_request_logs_api_key FOREIGN KEY (api_key_id) REFERENCES api_keys(id) ON DELETE SET NULL
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE request_logs IS 'High-volume log of API requests, partitioned by month on created_at.';
COMMENT ON COLUMN request_logs.id IS 'Using BIGSERIAL instead of UUID for better write performance and smaller index sizes at scale.';
COMMENT ON COLUMN request_logs.created_at IS 'Included in PK for partitioning.';
