-- tests/test_rate_limit_function.sql
-- Comprehensive test script for check_rate_limit function

DO $$ 
DECLARE
    passed_tests INT := 0;
    total_tests INT := 7;
    test_client_id UUID;
    test_endpoint_id INT;
    v_allowed BOOLEAN;
    v_remaining INT;
    v_retry_after INT;
BEGIN
    RAISE NOTICE '--- Starting Rate Limit Function Tests ---';

    -- Setup: Create a dedicated test client and endpoint to avoid interfering with seed data
    INSERT INTO plans (name, max_requests_per_minute) VALUES ('test_plan', 100) ON CONFLICT DO NOTHING;
    
    INSERT INTO clients (name, email, plan_id) 
    SELECT 'Test Client RL', 'testrl@example.com', id FROM plans WHERE name = 'test_plan'
    RETURNING id INTO test_client_id;
    
    INSERT INTO endpoints (path, method) VALUES ('/api/v1/test_rl', 'GET')
    RETURNING id INTO test_endpoint_id;
    
    INSERT INTO rate_limit_rules (endpoint_id, plan_id, max_requests, window_seconds)
    SELECT test_endpoint_id, id, 5, 60 FROM plans WHERE name = 'test_plan';

    -- Test 1: Check allowed = true for a fresh client with tokens available
    BEGIN
        SELECT allowed, remaining_tokens, retry_after_seconds 
        INTO v_allowed, v_remaining, v_retry_after
        FROM check_rate_limit(test_client_id, test_endpoint_id);
        
        IF v_allowed = true AND v_remaining = 4 THEN
            RAISE NOTICE 'PASS: Test 1 - Fresh client allowed';
            passed_tests := passed_tests + 1;
        ELSE
            RAISE NOTICE 'FAIL: Test 1 - Expected allowed=true, remaining=4, got allowed=%, remaining=%', v_allowed, v_remaining;
        END IF;
    END;

    -- Test 2: Exhaust all tokens
    BEGIN
        -- Consume remaining 4 tokens
        PERFORM check_rate_limit(test_client_id, test_endpoint_id);
        PERFORM check_rate_limit(test_client_id, test_endpoint_id);
        PERFORM check_rate_limit(test_client_id, test_endpoint_id);
        PERFORM check_rate_limit(test_client_id, test_endpoint_id);
        
        -- This one should fail
        SELECT allowed INTO v_allowed FROM check_rate_limit(test_client_id, test_endpoint_id);
        
        IF v_allowed = false THEN
            RAISE NOTICE 'PASS: Test 2 - Exhausted tokens denied';
            passed_tests := passed_tests + 1;
        ELSE
            RAISE NOTICE 'FAIL: Test 2 - Expected allowed=false after exhausting tokens';
        END IF;
    END;

    -- Test 3: Verify retry_after_seconds > 0 when denied
    BEGIN
        SELECT allowed, retry_after_seconds INTO v_allowed, v_retry_after 
        FROM check_rate_limit(test_client_id, test_endpoint_id);
        
        IF v_allowed = false AND v_retry_after > 0 THEN
            RAISE NOTICE 'PASS: Test 3 - retry_after_seconds > 0 (%)', v_retry_after;
            passed_tests := passed_tests + 1;
        ELSE
            RAISE NOTICE 'FAIL: Test 3 - Expected retry_after_seconds > 0, got %', v_retry_after;
        END IF;
    END;

    -- Test 4: Verify blocked client is denied immediately
    BEGIN
        INSERT INTO blocklist (client_id, reason, expires_at) 
        VALUES (test_client_id, 'Test block', now() + interval '1 hour');
        
        SELECT allowed INTO v_allowed FROM check_rate_limit(test_client_id, test_endpoint_id);
        
        IF v_allowed = false THEN
            RAISE NOTICE 'PASS: Test 4 - Blocked client denied immediately';
            passed_tests := passed_tests + 1;
        ELSE
            RAISE NOTICE 'FAIL: Test 4 - Blocked client was allowed';
        END IF;
        
        -- Cleanup blocklist for next tests
        DELETE FROM blocklist WHERE client_id = test_client_id;
    END;

    -- Test 5: Verify token refill
    BEGIN
        -- Manually manipulate the window to simulate time passing (65 seconds ago)
        UPDATE rate_limit_windows 
        SET last_request_at = now() - interval '65 seconds',
            available_tokens = 0
        WHERE client_id = test_client_id AND endpoint_id = test_endpoint_id;
        
        SELECT allowed, remaining_tokens INTO v_allowed, v_remaining 
        FROM check_rate_limit(test_client_id, test_endpoint_id);
        
        -- Max is 5, one consumed, remaining should be 4
        IF v_allowed = true AND v_remaining = 4 THEN
            RAISE NOTICE 'PASS: Test 5 - Token refill successful';
            passed_tests := passed_tests + 1;
        ELSE
            RAISE NOTICE 'FAIL: Test 5 - Expected allowed=true, remaining=4, got allowed=%, remaining=%', v_allowed, v_remaining;
        END IF;
    END;

    -- Test 6: Boundary test at EXACTLY the limit
    BEGIN
        -- Set to exactly 1 token left
        UPDATE rate_limit_windows 
        SET available_tokens = 1, last_request_at = now()
        WHERE client_id = test_client_id AND endpoint_id = test_endpoint_id;
        
        -- N succeeds
        SELECT allowed INTO v_allowed FROM check_rate_limit(test_client_id, test_endpoint_id);
        
        IF v_allowed = true THEN
            -- N+1 fails
            SELECT allowed INTO v_allowed FROM check_rate_limit(test_client_id, test_endpoint_id);
            IF v_allowed = false THEN
                RAISE NOTICE 'PASS: Test 6 - Boundary test (N succeeds, N+1 fails)';
                passed_tests := passed_tests + 1;
            ELSE
                RAISE NOTICE 'FAIL: Test 6 - Boundary test N+1 succeeded, should have failed';
            END IF;
        ELSE
            RAISE NOTICE 'FAIL: Test 6 - Boundary test N failed, should have succeeded';
        END IF;
    END;

    -- Test 7: Concurrent safety test
    BEGIN
        -- We can't fully test concurrency in a single PL/pgSQL block without dblink or pg_background,
        -- but we can test the atomic UPDATE...RETURNING logic by ensuring it correctly decrements
        UPDATE rate_limit_windows 
        SET available_tokens = 5, last_request_at = now()
        WHERE client_id = test_client_id AND endpoint_id = test_endpoint_id;
        
        SAVEPOINT sync_test;
        -- Simulate two back-to-back calls inside transaction
        SELECT allowed INTO v_allowed FROM check_rate_limit(test_client_id, test_endpoint_id);
        SELECT remaining_tokens INTO v_remaining FROM check_rate_limit(test_client_id, test_endpoint_id);
        
        IF v_remaining = 3 THEN
            RAISE NOTICE 'PASS: Test 7 - Atomic decrement (simulated concurrency)';
            passed_tests := passed_tests + 1;
        ELSE
            RAISE NOTICE 'FAIL: Test 7 - Expected 3 tokens remaining, got %', v_remaining;
        END IF;
        ROLLBACK TO sync_test;
    END;

    -- Cleanup test data
    DELETE FROM rate_limit_rules WHERE endpoint_id = test_endpoint_id;
    DELETE FROM endpoints WHERE id = test_endpoint_id;
    DELETE FROM clients WHERE id = test_client_id;
    
    RAISE NOTICE '--- Summary: %/% tests passed ---', passed_tests, total_tests;
    
    IF passed_tests < total_tests THEN
        RAISE EXCEPTION 'Some tests failed!';
    END IF;
END $$;
