-- File: views/v_client_usage_summary.sql
-- Description: View summarizing client API usage and plan metrics.

CREATE OR REPLACE VIEW v_client_usage_summary AS
WITH client_api_keys AS (
    SELECT client_id, COUNT(*) AS active_api_keys
    FROM api_keys
    WHERE revoked_at IS NULL
    GROUP BY client_id
),
recent_requests AS (
    SELECT 
        r.client_id,
        p.window_seconds,
        COUNT(*) FILTER (WHERE r.created_at >= NOW() - INTERVAL '1 hour') AS requests_last_1h,
        COUNT(*) FILTER (WHERE r.created_at >= NOW() - INTERVAL '24 hours') AS requests_last_24h,
        COUNT(*) FILTER (WHERE r.created_at >= NOW() - INTERVAL '24 hours' AND r.status_code >= 400)::NUMERIC / 
            NULLIF(COUNT(*) FILTER (WHERE r.created_at >= NOW() - INTERVAL '24 hours'), 0) AS error_rate_24h,
        AVG(r.response_time_ms) FILTER (WHERE r.created_at >= NOW() - INTERVAL '24 hours') AS avg_response_time_ms,
        COUNT(*) FILTER (WHERE r.created_at >= NOW() - (p.window_seconds || ' seconds')::INTERVAL) AS requests_last_window
    FROM request_logs r
    JOIN clients c ON r.client_id = c.id
    JOIN plans p ON c.plan_id = p.id
    WHERE r.created_at >= NOW() - INTERVAL '24 hours'
    GROUP BY r.client_id, p.window_seconds
),
client_abuse_flags AS (
    SELECT client_id, COUNT(*) AS open_abuse_flags
    FROM abuse_flags
    WHERE resolved_at IS NULL
    GROUP BY client_id
)
SELECT 
    c.id AS client_id,
    c.name,
    c.email,
    p.name AS plan_name,
    p.requests_per_window,
    p.window_seconds,
    COALESCE(ak.active_api_keys, 0) AS active_api_keys,
    COALESCE(rr.requests_last_1h, 0) AS requests_last_1h,
    COALESCE(rr.requests_last_24h, 0) AS requests_last_24h,
    COALESCE(rr.error_rate_24h, 0.0) AS error_rate_24h,
    rr.avg_response_time_ms,
    c.is_blocked,
    COALESCE(af.open_abuse_flags, 0) AS open_abuse_flags,
    (COALESCE(rr.requests_last_window, 0)::NUMERIC / NULLIF(p.requests_per_window, 0)) * 100 AS usage_percent
FROM clients c
JOIN plans p ON c.plan_id = p.id
LEFT JOIN client_api_keys ak ON c.id = ak.client_id
LEFT JOIN recent_requests rr ON c.id = rr.client_id
LEFT JOIN client_abuse_flags af ON c.id = af.client_id
ORDER BY 
    COALESCE(rr.requests_last_24h, 0) DESC;
