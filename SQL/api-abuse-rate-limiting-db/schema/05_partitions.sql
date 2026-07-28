-- schema/05_partitions.sql

-- Create monthly partitions for request_logs covering Jul 2025 – Dec 2026.
-- Plus a default partition for data falling outside these ranges.

CREATE TABLE request_logs_2025_07 PARTITION OF request_logs FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE request_logs_2025_08 PARTITION OF request_logs FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE request_logs_2025_09 PARTITION OF request_logs FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE request_logs_2025_10 PARTITION OF request_logs FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE request_logs_2025_11 PARTITION OF request_logs FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE request_logs_2025_12 PARTITION OF request_logs FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

CREATE TABLE request_logs_2026_01 PARTITION OF request_logs FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE request_logs_2026_02 PARTITION OF request_logs FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE request_logs_2026_03 PARTITION OF request_logs FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE request_logs_2026_04 PARTITION OF request_logs FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE request_logs_2026_05 PARTITION OF request_logs FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE request_logs_2026_06 PARTITION OF request_logs FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE request_logs_2026_07 PARTITION OF request_logs FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE request_logs_2026_08 PARTITION OF request_logs FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE request_logs_2026_09 PARTITION OF request_logs FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE request_logs_2026_10 PARTITION OF request_logs FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE request_logs_2026_11 PARTITION OF request_logs FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE request_logs_2026_12 PARTITION OF request_logs FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

CREATE TABLE request_logs_default PARTITION OF request_logs DEFAULT;

-- Function to programmatically create the next partition if it doesn't already exist.
CREATE OR REPLACE FUNCTION create_monthly_partition(target_month DATE)
RETURNS VOID AS $$
DECLARE
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    start_date := date_trunc('month', target_month);
    end_date := start_date + INTERVAL '1 month';
    partition_name := 'request_logs_' || to_char(start_date, 'YYYY_MM');

    IF NOT EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = partition_name
    ) THEN
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF request_logs FOR VALUES FROM (%L) TO (%L);',
            partition_name, start_date, end_date
        );
    END IF;
END;
$$ LANGUAGE plpgsql;
