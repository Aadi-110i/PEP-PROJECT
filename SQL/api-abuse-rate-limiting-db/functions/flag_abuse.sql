-- =============================================================================
-- FILE: functions/flag_abuse.sql
-- PURPOSE: Idempotent abuse flagging with optional auto-block for critical cases.
-- ENGINE:  PostgreSQL 15+
-- =============================================================================

CREATE OR REPLACE FUNCTION flag_abuse(
    p_client_id   UUID,
    p_endpoint_id UUID    DEFAULT NULL,
    p_reason      TEXT    DEFAULT 'Automated abuse detection',
    p_severity    VARCHAR DEFAULT 'medium',
    p_details     JSONB   DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_flag_id       UUID;
    v_existing_id   UUID;
    v_client_exists BOOLEAN;
BEGIN
    -- -------------------------------------------------------------------------
    -- Guard: ensure the client actually exists
    -- -------------------------------------------------------------------------
    SELECT EXISTS (SELECT 1 FROM clients WHERE id = p_client_id)
    INTO   v_client_exists;

    IF NOT v_client_exists THEN
        RAISE EXCEPTION 'flag_abuse: client % does not exist', p_client_id;
    END IF;

    -- -------------------------------------------------------------------------
    -- Idempotency check: look for an UNRESOLVED flag for the same
    -- (client, endpoint, reason) raised within the last 60 minutes.
    -- This prevents a burst of duplicate flags from a noisy trigger.
    -- -------------------------------------------------------------------------
    SELECT id
    INTO   v_existing_id
    FROM   abuse_flags
    WHERE  client_id    = p_client_id
      AND  (endpoint_id = p_endpoint_id OR (endpoint_id IS NULL AND p_endpoint_id IS NULL))
      AND  reason       = p_reason
      AND  resolved_at  IS NULL
      AND  detected_at  > now() - INTERVAL '60 minutes'
    ORDER BY detected_at DESC
    LIMIT 1;

    IF FOUND THEN
        -- Refresh the timestamp and merge details on the existing flag
        UPDATE abuse_flags
        SET
            detected_at = now(),
            details     = details || p_details,
            -- Escalate severity if the new call is higher
            severity = CASE
                WHEN p_severity = 'critical'                          THEN 'critical'
                WHEN p_severity = 'high'    AND severity != 'critical' THEN 'high'
                WHEN p_severity = 'medium'  AND severity NOT IN ('critical','high') THEN 'medium'
                ELSE severity
            END,
            updated_at  = now()
        WHERE id = v_existing_id;

        v_flag_id := v_existing_id;
    ELSE
        -- Insert a new flag
        INSERT INTO abuse_flags (
            client_id,
            endpoint_id,
            reason,
            severity,
            details,
            detected_at
        )
        VALUES (
            p_client_id,
            p_endpoint_id,
            p_reason,
            p_severity,
            p_details,
            now()
        )
        RETURNING id INTO v_flag_id;
    END IF;

    -- -------------------------------------------------------------------------
    -- CRITICAL auto-escalation:
    --   If severity = 'critical', immediately block the client and add
    --   a 24-hour blocklist entry.
    -- -------------------------------------------------------------------------
    IF p_severity = 'critical' THEN
        -- Block the client account
        UPDATE clients
        SET
            is_blocked    = TRUE,
            blocked_at    = now(),
            blocked_reason = format('Auto-blocked: %s', p_reason),
            updated_at    = now()
        WHERE id = p_client_id
          AND is_blocked = FALSE;  -- only if not already blocked

        -- Add a blocklist entry (upsert by client_id to avoid duplicates)
        INSERT INTO blocklist (
            client_id,
            reason,
            blocked_at,
            expires_at,
            blocked_by,
            is_active
        )
        VALUES (
            p_client_id,
            format('Critical abuse flag: %s', p_reason),
            now(),
            now() + INTERVAL '24 hours',
            'system:auto-flag',
            TRUE
        )
        ON CONFLICT DO NOTHING;

        -- Audit the auto-block
        INSERT INTO audit_log (
            entity_type,
            entity_id,
            action,
            new_values,
            changed_by
        )
        VALUES (
            'clients',
            p_client_id,
            'UPDATE',
            jsonb_build_object(
                'is_blocked',     TRUE,
                'blocked_reason', format('Auto-blocked: %s', p_reason),
                'flag_id',        v_flag_id
            ),
            'system:flag_abuse'
        );
    END IF;

    RETURN v_flag_id;
END;
$$;

COMMENT ON FUNCTION flag_abuse(UUID, UUID, TEXT, VARCHAR, JSONB) IS
    'Idempotent abuse flag creation. '
    'Deduplicates flags with the same (client, endpoint, reason) raised within 60 minutes. '
    'For critical severity: auto-blocks the client, inserts a 24-hour blocklist entry, '
    'and writes an audit log record. Returns the flag UUID.';
