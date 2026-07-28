-- File: views/v_active_abusers.sql
-- Description: View showing currently active abusers with unresolved flags.

CREATE OR REPLACE VIEW v_active_abusers AS
WITH recent_stats AS (
    SELECT 
        client_id,
        COUNT(*) AS total_requests_last_24h,
        COUNT(*) FILTER (WHERE status_code >= 400)::NUMERIC / NULLIF(COUNT(*), 0) AS error_rate_last_24h
    FROM request_logs
    WHERE created_at >= NOW() - INTERVAL '24 hours'
    GROUP BY client_id
),
flag_stats AS (
    SELECT 
        client_id,
        COUNT(*) AS open_flag_count,
        MAX(
            CASE severity
                WHEN 'critical' THEN 4
                WHEN 'high' THEN 3
                WHEN 'medium' THEN 2
                WHEN 'low' THEN 1
                ELSE 0
            END
        ) AS highest_severity_score,
        MAX(created_at) AS most_recent_flag_at
    FROM abuse_flags
    WHERE resolved_at IS NULL
    GROUP BY client_id
)
SELECT 
    c.id AS client_id,
    c.name AS client_name,
    c.email,
    p.name AS plan_name,
    f.open_flag_count,
    CASE f.highest_severity_score
        WHEN 4 THEN 'critical'
        WHEN 3 THEN 'high'
        WHEN 2 THEN 'medium'
        WHEN 1 THEN 'low'
        ELSE 'unknown'
    END AS highest_severity,
    f.most_recent_flag_at,
    c.is_blocked,
    COALESCE(rs.total_requests_last_24h, 0) AS total_requests_last_24h,
    COALESCE(rs.error_rate_last_24h, 0.0) AS error_rate_last_24h
FROM flag_stats f
JOIN clients c ON f.client_id = c.id
JOIN plans p ON c.plan_id = p.id
LEFT JOIN recent_stats rs ON c.id = rs.client_id
ORDER BY 
    f.highest_severity_score DESC, 
    f.open_flag_count DESC;
