-- File: triggers/trg_auto_flag_abuse.sql
-- Description: Trigger to automatically flag abuse based on request patterns.
-- Note: Triggers add per-insert overhead. In ultra-high-volume systems, this logic
-- might move to a periodic background job, stream processing, or an async queue.
-- But for portfolio purposes to demonstrate SQL capabilities, this is correct and impressive.

CREATE OR REPLACE FUNCTION auto_flag_abuse_fn()
RETURNS TRIGGER AS $$
DECLARE
    v_total_count INT;
    v_error_count INT;
    v_error_ratio NUMERIC;
    v_rate_limit_count INT;
BEGIN
    -- 1. Count requests from NEW.client_id to NEW.endpoint_id in the last 60 seconds
    SELECT COUNT(*) INTO v_total_count
    FROM request_logs
    WHERE client_id = NEW.client_id
      AND endpoint_id = NEW.endpoint_id
      AND created_at >= NOW() - INTERVAL '60 seconds';

    -- 2. Count 4xx/5xx responses from same client+endpoint in last 60 seconds
    SELECT COUNT(*) INTO v_error_count
    FROM request_logs
    WHERE client_id = NEW.client_id
      AND endpoint_id = NEW.endpoint_id
      AND status_code >= 400
      AND created_at >= NOW() - INTERVAL '60 seconds';

    -- 3. Calculate error_ratio
    v_error_ratio := v_error_count::NUMERIC / NULLIF(v_total_count, 0);

    -- 4. Check for high request volume
    IF v_total_count > 100 THEN
        INSERT INTO abuse_flags (client_id, endpoint_id, reason, severity, created_at, updated_at)
        VALUES (NEW.client_id, NEW.endpoint_id, 'High request volume detected', 'high', NOW(), NOW());
    END IF;

    -- 5. Check for high error rate
    IF v_error_ratio > 0.5 AND v_total_count > 20 THEN
        INSERT INTO abuse_flags (client_id, endpoint_id, reason, severity, created_at, updated_at)
        VALUES (NEW.client_id, NEW.endpoint_id, 'High error rate detected', 'medium', NOW(), NOW());
    END IF;

    -- 6. Check for persistent rate limit violations
    IF NEW.status_code = 429 THEN
        SELECT COUNT(*) INTO v_rate_limit_count
        FROM request_logs
        WHERE client_id = NEW.client_id
          AND status_code = 429
          AND created_at >= NOW() - INTERVAL '5 minutes';

        IF v_rate_limit_count > 50 THEN
            INSERT INTO abuse_flags (client_id, endpoint_id, reason, severity, created_at, updated_at)
            VALUES (NEW.client_id, NEW.endpoint_id, 'Persistent rate limit violations', 'critical', NOW(), NOW());
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_flag_abuse ON request_logs;
CREATE TRIGGER trg_auto_flag_abuse
AFTER INSERT ON request_logs
FOR EACH ROW
EXECUTE FUNCTION auto_flag_abuse_fn();
