-- File: triggers/trg_update_last_seen.sql
-- Description: Trigger to update last_used_at and updated_at based on request_logs.

CREATE OR REPLACE FUNCTION update_last_seen_fn()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. UPDATE api_keys SET last_used_at
    IF NEW.api_key_id IS NOT NULL THEN
        UPDATE api_keys
        SET last_used_at = NEW.created_at
        WHERE id = NEW.api_key_id
          AND (last_used_at IS NULL OR last_used_at < NEW.created_at);
    END IF;

    -- 2. UPDATE clients SET updated_at
    UPDATE clients
    SET updated_at = NEW.created_at
    WHERE id = NEW.client_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_last_seen ON request_logs;
CREATE TRIGGER trg_update_last_seen
AFTER INSERT ON request_logs
FOR EACH ROW
EXECUTE FUNCTION update_last_seen_fn();
