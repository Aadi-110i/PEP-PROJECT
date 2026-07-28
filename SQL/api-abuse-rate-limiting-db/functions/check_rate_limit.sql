-- =============================================================================
-- FILE: functions/check_rate_limit.sql
-- PURPOSE: Token-bucket rate-limit check — atomic, race-condition safe.
-- ENGINE:  PostgreSQL 15+
-- =============================================================================
--
-- CONCURRENCY SAFETY ANALYSIS
-- ────────────────────────────
-- The core check-and-decrement is implemented as a single
-- INSERT ... ON CONFLICT (client_id, endpoint_id) DO UPDATE ... RETURNING
-- statement.  PostgreSQL guarantees:
--
--   1. The INSERT either succeeds (new row) or the ON CONFLICT branch fires —
--      never both for the same key.
--   2. When the ON CONFLICT branch fires, PostgreSQL holds a tuple-level
--      exclusive lock on the existing row for the duration of the statement.
--      A concurrent transaction attempting the same upsert will BLOCK until
--      the lock is released (i.e., until the first statement commits/rolls
--      back).  It then operates on the post-decrement value.
--   3. Therefore no two concurrent callers can both see tokens_remaining > 0
--      and both succeed when the bucket is at exactly 1 token.  The second
--      caller will see tokens_remaining = 0 (or negative) after the first
--      caller's decrement has committed.
--
-- This eliminates the TOCTOU race that would exist if we used a separate
-- SELECT ... FOR UPDATE followed by an UPDATE.
--
-- ALGORITHM: Token Bucket
-- ───────────────────────
-- Capacity  C  = limit_requests  (from matching rule or endpoint default)
-- Refill    R  = C tokens per window_seconds
-- Each request consumes 1 token.
-- On every call we:
--   1. Calculate how many tokens have been refilled since last_request_at:
--        refill = FLOOR(elapsed_seconds / window_seconds * C)
--   2. Clamp: new_balance = LEAST(tokens_remaining + refill, C)
--   3. Decrement by 1.
--   4. If balance after decrement >= 0 → ALLOWED, else → DENIED.
-- =============================================================================

CREATE OR REPLACE FUNCTION check_rate_limit(
    p_client_id   UUID,
    p_endpoint_id UUID
)
RETURNS TABLE (
    allowed              BOOLEAN,
    tokens_remaining     INT,
    retry_after_seconds  INT,
    reason               TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_limit          INT;
    v_window_seconds INT;
    v_algorithm      VARCHAR(20);
    v_burst          INT;
    v_tokens_after   INT;
    v_window_start   TIMESTAMPTZ;
    v_window_end     TIMESTAMPTZ;
    v_elapsed        FLOAT;
    v_refill         INT;
    v_is_blocked     BOOLEAN;
BEGIN
    -- -------------------------------------------------------------------------
    -- STEP 1: Blocklist check — fast-path denial for banned clients
    -- -------------------------------------------------------------------------
    SELECT EXISTS (
        SELECT 1
        FROM blocklist bl
        WHERE bl.is_active = TRUE
          AND (bl.expires_at IS NULL OR bl.expires_at > now())
          AND (
              bl.client_id = p_client_id
              OR bl.ip_address IS NOT NULL  -- IP check must be done at app layer
          )
        LIMIT 1
    ) INTO v_is_blocked;

    IF v_is_blocked THEN
        RETURN QUERY SELECT FALSE, 0, 3600, 'Client is blocklisted';
        RETURN;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 2: Resolve the highest-priority matching rate-limit rule
    --
    -- Precedence (higher priority INT wins):
    --   client + endpoint  →  client-only  →  endpoint-only  →  global (NULL/NULL)
    -- -------------------------------------------------------------------------
    SELECT
        rlr.limit_requests,
        rlr.window_seconds,
        rlr.algorithm,
        rlr.burst_allowance
    INTO
        v_limit, v_window_seconds, v_algorithm, v_burst
    FROM rate_limit_rules rlr
    WHERE rlr.is_active = TRUE
      AND (rlr.client_id   = p_client_id   OR rlr.client_id   IS NULL)
      AND (rlr.endpoint_id = p_endpoint_id OR rlr.endpoint_id IS NULL)
    ORDER BY rlr.priority DESC
    LIMIT 1;

    -- Fallback: use endpoint defaults
    IF NOT FOUND THEN
        SELECT e.default_limit, e.default_window_seconds
        INTO   v_limit, v_window_seconds
        FROM   endpoints e
        WHERE  e.id = p_endpoint_id;

        v_algorithm := 'token_bucket';
        v_burst     := 0;
    END IF;

    -- If still nothing (unknown endpoint), use a conservative global default
    IF v_limit IS NULL THEN
        v_limit          := 60;
        v_window_seconds := 60;
        v_algorithm      := 'token_bucket';
        v_burst          := 0;
    END IF;

    -- -------------------------------------------------------------------------
    -- STEP 3: Atomic token-bucket upsert
    --
    -- Single statement → single tuple lock → race-condition safe.
    --
    -- On INSERT (first request ever): seed with full bucket minus 1 token.
    -- On UPDATE (existing row):
    --   a. Calculate refill based on elapsed time since last_request_at.
    --   b. Clamp to capacity (v_limit + v_burst).
    --   c. Decrement by 1.
    -- -------------------------------------------------------------------------
    INSERT INTO rate_limit_windows AS rlw (
        client_id,
        endpoint_id,
        window_start,
        window_end,
        request_count,
        tokens_remaining,
        last_request_at,
        algorithm
    )
    VALUES (
        p_client_id,
        p_endpoint_id,
        now(),
        now() + (v_window_seconds || ' seconds')::INTERVAL,
        1,                           -- first request
        v_limit + v_burst - 1,       -- full bucket minus 1
        now(),
        v_algorithm
    )
    ON CONFLICT (client_id, endpoint_id) DO UPDATE
        SET
            -- Compute how many tokens have been refilled since last request
            tokens_remaining = LEAST(
                -- Clamp to capacity
                v_limit + v_burst,
                -- Current balance + refill amount
                rlw.tokens_remaining + GREATEST(
                    0,
                    FLOOR(
                        EXTRACT(EPOCH FROM (now() - rlw.last_request_at))
                        / v_window_seconds
                        * v_limit
                    )::INT
                )
            ) - 1,   -- ← consume 1 token atomically
            request_count   = rlw.request_count + 1,
            last_request_at = now(),
            window_start    = CASE
                                  WHEN now() > rlw.window_end
                                  THEN now()
                                  ELSE rlw.window_start
                              END,
            window_end      = CASE
                                  WHEN now() > rlw.window_end
                                  THEN now() + (v_window_seconds || ' seconds')::INTERVAL
                                  ELSE rlw.window_end
                              END,
            algorithm       = v_algorithm
    RETURNING tokens_remaining
    INTO v_tokens_after;

    -- -------------------------------------------------------------------------
    -- STEP 4: Evaluate result
    -- -------------------------------------------------------------------------
    IF v_tokens_after >= 0 THEN
        -- Allowed: return remaining tokens after this request
        RETURN QUERY
            SELECT
                TRUE,
                v_tokens_after,
                0,
                NULL::TEXT;
    ELSE
        -- Denied: roll back the over-spend to 0 (bucket floor)
        UPDATE rate_limit_windows
        SET    tokens_remaining = 0
        WHERE  client_id   = p_client_id
          AND  endpoint_id = p_endpoint_id;

        RETURN QUERY
            SELECT
                FALSE,
                0,
                v_window_seconds,
                format(
                    'Rate limit exceeded: %s requests per %s seconds',
                    v_limit,
                    v_window_seconds
                );
    END IF;
END;
$$;

COMMENT ON FUNCTION check_rate_limit(UUID, UUID) IS
    'Atomically checks and decrements the token bucket for a (client, endpoint) pair. '
    'Returns allowed=true with remaining tokens, or allowed=false with retry_after_seconds. '
    'Race-condition safe: uses a single INSERT...ON CONFLICT DO UPDATE...RETURNING statement '
    'which PostgreSQL executes under a tuple-level exclusive lock.';
