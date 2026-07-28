-- =============================================================================
-- FILE: functions/cleanup_old_logs.sql
-- PURPOSE: Drop old request_logs partitions and remove stale operational rows.
-- ENGINE:  PostgreSQL 15+
-- =============================================================================
--
-- STRATEGY
-- ─────────
-- request_logs is partitioned by month (RANGE on created_at).
-- Rather than DELETE-ing millions of rows (slow, bloat, WAL pressure),
-- we DROP entire old partitions with a single DDL statement per partition.
-- PostgreSQL releases the storage immediately — no VACUUM needed.
--
-- In addition to partition cleanup this function:
--   • Removes stale rate_limit_windows rows (idle clients we no longer track)
--   • Removes resolved abuse_flags older than the retention window
-- =============================================================================

CREATE OR REPLACE FUNCTION cleanup_old_logs(
    p_retention_days INT DEFAULT 90
)
RETURNS TABLE (
    partitions_dropped   INT,
    rl_windows_deleted   BIGINT,
    abuse_flags_deleted  BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cutoff            TIMESTAMPTZ;
    v_partition_name    TEXT;
    v_partition_rel     OID;
    v_partition_min_val TEXT;
    v_partitions_dropped INT := 0;
    v_rl_windows_deleted BIGINT := 0;
    v_flags_deleted      BIGINT := 0;
    v_sql                TEXT;
BEGIN
    v_cutoff := now() - (p_retention_days || ' days')::INTERVAL;

    -- -------------------------------------------------------------------------
    -- STEP 1: Find and drop old request_logs monthly partitions
    --
    -- We query pg_inherits to find all child tables of request_logs,
    -- then check pg_get_expr(relpartbound) to read the partition boundary
    -- and compare it with the cutoff date.
    -- -------------------------------------------------------------------------
    FOR v_partition_name, v_partition_rel IN
        SELECT
            c.relname,
            c.oid
        FROM   pg_inherits  pi
        JOIN   pg_class     c  ON c.oid  = pi.inhrelid
        JOIN   pg_class     pc ON pc.oid = pi.inhparent
        WHERE  pc.relname = 'request_logs'
          AND  c.relkind  = 'r'
    LOOP
        -- Extract the upper bound of the partition range
        SELECT pg_get_expr(c.relpartbound, c.oid)
        INTO   v_partition_min_val
        FROM   pg_class c
        WHERE  c.oid = v_partition_rel;

        -- The expression looks like: FOR VALUES FROM ('2025-07-01') TO ('2025-08-01')
        -- We drop the partition only if its upper bound is before the cutoff.
        IF v_partition_min_val ~ 'TO \(''(\d{4}-\d{2}-\d{2})''' THEN
            DECLARE
                v_upper_bound TIMESTAMPTZ;
            BEGIN
                v_upper_bound := (
                    SELECT (regexp_match(v_partition_min_val, 'TO \(''(\d{4}-\d{2}-\d{2})'))[1]
                )::TIMESTAMPTZ;

                IF v_upper_bound < v_cutoff THEN
                    v_sql := format('DROP TABLE IF EXISTS %I', v_partition_name);
                    RAISE NOTICE 'Dropping old partition: % (upper bound: %)',
                        v_partition_name, v_upper_bound;
                    EXECUTE v_sql;
                    v_partitions_dropped := v_partitions_dropped + 1;
                END IF;
            END;
        END IF;
    END LOOP;

    -- -------------------------------------------------------------------------
    -- STEP 2: Remove stale rate_limit_windows rows
    --
    -- If a client has not made a request in p_retention_days days, its window
    -- state is stale. Remove it so the table stays small (it's the hot-path
    -- table and should fit in shared_buffers).
    -- -------------------------------------------------------------------------
    DELETE FROM rate_limit_windows
    WHERE last_request_at < v_cutoff
       OR last_request_at IS NULL;

    GET DIAGNOSTICS v_rl_windows_deleted = ROW_COUNT;

    -- -------------------------------------------------------------------------
    -- STEP 3: Remove old resolved abuse_flags
    --
    -- Unresolved flags are kept indefinitely (they need human review).
    -- Resolved flags older than the retention window can be purged.
    -- -------------------------------------------------------------------------
    DELETE FROM abuse_flags
    WHERE resolved_at IS NOT NULL
      AND resolved_at < v_cutoff;

    GET DIAGNOSTICS v_flags_deleted = ROW_COUNT;

    -- -------------------------------------------------------------------------
    -- STEP 4: Log the cleanup in the audit log
    -- -------------------------------------------------------------------------
    INSERT INTO audit_log (
        entity_type,
        entity_id,
        action,
        new_values,
        changed_by
    )
    VALUES (
        'maintenance',
        NULL,
        'DELETE',
        jsonb_build_object(
            'operation',           'cleanup_old_logs',
            'retention_days',      p_retention_days,
            'cutoff_date',         v_cutoff,
            'partitions_dropped',  v_partitions_dropped,
            'rl_windows_deleted',  v_rl_windows_deleted,
            'abuse_flags_deleted', v_flags_deleted,
            'executed_at',         now()
        ),
        'system:cleanup_old_logs'
    );

    RETURN QUERY
        SELECT v_partitions_dropped, v_rl_windows_deleted, v_flags_deleted;
END;
$$;

COMMENT ON FUNCTION cleanup_old_logs(INT) IS
    'Maintenance function: drops request_logs partitions older than p_retention_days, '
    'removes stale rate_limit_windows rows for inactive clients, and purges old resolved '
    'abuse_flags. Returns counts of affected objects. Safe to run repeatedly. '
    'Recommended schedule: weekly (e.g. via pg_cron every Sunday at 03:00).';
