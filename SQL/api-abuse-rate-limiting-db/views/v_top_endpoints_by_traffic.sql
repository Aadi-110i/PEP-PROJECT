-- File: views/v_top_endpoints_by_traffic.sql
-- Description: View showing top endpoints by traffic over the last 24 hours.

CREATE OR REPLACE VIEW v_top_endpoints_by_traffic AS
SELECT 
    e.id AS endpoint_id,
    e.path,
    e.method,
    COUNT(r.id) AS total_requests,
    COUNT(DISTINCT r.client_id) AS unique_clients,
    AVG(r.response_time_ms) AS avg_response_time_ms,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY r.response_time_ms) AS p95_response_time_ms,
    COUNT(*) FILTER (WHERE r.status_code >= 400)::NUMERIC / NULLIF(COUNT(r.id), 0) AS error_rate,
    COUNT(*) FILTER (WHERE r.status_code = 429) AS rate_limited_count,
    COUNT(r.id)::NUMERIC / (24 * 60) AS requests_per_minute
FROM endpoints e
JOIN request_logs r ON e.id = r.endpoint_id
WHERE r.created_at >= NOW() - INTERVAL '24 hours'
GROUP BY 
    e.id, 
    e.path, 
    e.method
ORDER BY 
    total_requests DESC;
