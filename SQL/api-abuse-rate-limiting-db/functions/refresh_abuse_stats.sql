-- =========================================================================
-- FUNCTION: refresh_abuse_stats
-- =========================================================================
-- Creates (if needed) and refreshes a materialized view of abuse stats,
-- and triggers automated flags/blocks based on analyzed patterns.
-- =========================================================================

CREATE OR REPLACE FUNCTION refresh_abuse_stats()
RETURNS void AS $$
BEGIN
    -- 1. Create materialized view if not exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = 'mv_abuse_stats' AND relkind = 'm'
    ) THEN
        CREATE MATERIALIZED VIEW mv_abuse_stats AS
        SELECT 
            rl.client_id,
            COUNT(*) AS total_requests_24h,
            SUM(CASE WHEN rl.status_code >= 400 THEN 1 ELSE 0 END)::FLOAT / GREATEST(COUNT(*), 1) AS error_rate_24h,
            (SELECT COUNT(*) FROM abuse_flags af WHERE af.client_id = rl.client_id) AS flagged_count,
            (
                SELECT severity 
                FROM abuse_flags af 
                WHERE af.client_id = rl.client_id 
                ORDER BY detected_at DESC LIMIT 1
            ) AS last_flag_severity,
            now() AS computed_at
        FROM request_logs rl
        WHERE rl.created_at >= now() - interval '24 hours'
        GROUP BY rl.client_id;
        
        -- Create unique index required for CONCURRENTLY
        CREATE UNIQUE INDEX idx_mv_abuse_stats_client_id ON mv_abuse_stats(client_id);
    END IF;

    -- 2. Refresh the materialized view
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_abuse_stats;

    -- 3. Update abuse_flags severity to 'critical' for high error rate + many flags
    UPDATE abuse_flags
    SET severity = 'critical',
        details = COALESCE(details, '{}'::jsonb) || '{"reason_updated": "High error rate and flag count in last 24h"}'::jsonb
    WHERE client_id IN (
        SELECT client_id 
        FROM mv_abuse_stats
        WHERE error_rate_24h > 0.5 
          AND flagged_count >= 3
    )
    AND severity != 'critical';

    -- 4. Call flag_abuse() for clients with > 1000 requests in last hour and no open flag
    PERFORM flag_abuse(
        sub.client_id,
        NULL,
        'High request volume: over 1000 requests in the last hour',
        'high'
    )
    FROM (
        SELECT client_id, COUNT(*) as req_count
        FROM request_logs
        WHERE created_at >= now() - interval '1 hour'
        GROUP BY client_id
        HAVING COUNT(*) > 1000
    ) sub
    WHERE NOT EXISTS (
        SELECT 1 FROM abuse_flags af 
        WHERE af.client_id = sub.client_id 
          AND af.resolved_at IS NULL
    );

END;
$$ LANGUAGE plpgsql;
