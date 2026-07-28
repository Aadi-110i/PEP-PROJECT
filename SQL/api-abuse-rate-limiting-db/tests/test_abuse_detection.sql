-- tests/test_abuse_detection.sql
-- Test script for abuse detection mechanisms

DO $$ 
DECLARE
    passed_tests INT := 0;
    total_tests INT := 5;
    test_client_id UUID;
    test_endpoint_id INT;
    v_flag_count INT;
    v_block_count INT;
    v_view_count INT;
BEGIN
    RAISE NOTICE '--- Starting Abuse Detection Tests ---';

    -- Setup Test Data
    INSERT INTO plans (name, max_requests_per_minute) VALUES ('abuse_test_plan', 1000) ON CONFLICT DO NOTHING;
    
    INSERT INTO clients (name, email, plan_id) 
    SELECT 'Abuse Test Client', 'abusetest@example.com', id FROM plans WHERE name = 'abuse_test_plan'
    RETURNING id INTO test_client_id;
    
    INSERT INTO endpoints (path, method) VALUES ('/api/v1/abuse_test', 'POST')
    RETURNING id INTO test_endpoint_id;

    -- Wrap tests in a subtransaction to easily rollback state
    BEGIN
        -- Test 1: Test trigger-based auto-flagging
        BEGIN
            -- Insert 101 request_log rows in rapid succession
            INSERT INTO request_logs (client_id, endpoint_id, ip_address, status_code, response_time_ms, created_at)
            SELECT test_client_id, test_endpoint_id, '192.168.1.100', 200, 10, now()
            FROM generate_series(1, 101);
            
            -- Call the trigger function manually or simulate the check
            -- Note: Assuming there's a scheduled job or trigger that calls flag_abuse
            -- For this test, we explicitly call flag_abuse to simulate the detector
            PERFORM flag_abuse(test_client_id, 'high', 'Detected > 100 requests in short window');
            
            SELECT count(*) INTO v_flag_count FROM abuse_flags WHERE client_id = test_client_id;
            IF v_flag_count > 0 THEN
                RAISE NOTICE 'PASS: Test 1 - Auto-flagging inserted abuse_flags row';
                passed_tests := passed_tests + 1;
            ELSE
                RAISE NOTICE 'FAIL: Test 1 - No abuse flag created';
            END IF;
        END;

        -- Test 2: Test flag_abuse() function directly (idempotency)
        BEGIN
            -- Call flag_abuse again with same args
            PERFORM flag_abuse(test_client_id, 'high', 'Detected > 100 requests in short window');
            
            SELECT count(*) INTO v_flag_count FROM abuse_flags 
            WHERE client_id = test_client_id AND severity = 'high';
            
            -- Should only be 1 active flag for this severity/reason within cooldown period
            IF v_flag_count = 1 THEN
                RAISE NOTICE 'PASS: Test 2 - flag_abuse is idempotent';
                passed_tests := passed_tests + 1;
            ELSE
                RAISE NOTICE 'FAIL: Test 2 - Expected 1 flag, got %', v_flag_count;
            END IF;
        END;

        -- Test 3: Test critical auto-block
        BEGIN
            PERFORM flag_abuse(test_client_id, 'critical', 'Malicious payload detected');
            
            SELECT count(*) INTO v_block_count FROM blocklist WHERE client_id = test_client_id;
            IF v_block_count > 0 THEN
                RAISE NOTICE 'PASS: Test 3 - Critical severity auto-blocked client';
                passed_tests := passed_tests + 1;
            ELSE
                RAISE NOTICE 'FAIL: Test 3 - Client was not added to blocklist';
            END IF;
        END;

        -- Test 4: View correctness (v_active_abusers)
        BEGIN
            -- Seeded data tests: check if our newly blocked client appears in the view
            SELECT count(*) INTO v_view_count FROM v_active_abusers WHERE client_id = test_client_id;
            
            IF v_view_count > 0 THEN
                RAISE NOTICE 'PASS: Test 4 - View v_active_abusers includes blocked client';
                passed_tests := passed_tests + 1;
            ELSE
                RAISE NOTICE 'FAIL: Test 4 - Client missing from v_active_abusers';
            END IF;
        END;

        -- Test 5: View correctness (v_top_endpoints_by_traffic)
        BEGIN
            SELECT count(*) INTO v_view_count 
            FROM v_top_endpoints_by_traffic 
            WHERE endpoint_id = test_endpoint_id;
            
            IF v_view_count > 0 THEN
                RAISE NOTICE 'PASS: Test 5 - View v_top_endpoints_by_traffic includes test endpoint';
                passed_tests := passed_tests + 1;
            ELSE
                RAISE NOTICE 'FAIL: Test 5 - Endpoint missing from v_top_endpoints_by_traffic';
            END IF;
        END;

        -- Rollback all test data modifications
        RAISE EXCEPTION 'Rollback Test Data';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'Rollback Test Data' THEN
            RAISE NOTICE 'Test data rolled back successfully.';
        ELSE
            RAISE;
        END IF;
    END;

    -- Cleanup base test data
    DELETE FROM endpoints WHERE id = test_endpoint_id;
    DELETE FROM clients WHERE id = test_client_id;

    RAISE NOTICE '--- Summary: %/% tests passed ---', passed_tests, total_tests;
    
    IF passed_tests < total_tests THEN
        RAISE EXCEPTION 'Some tests failed!';
    END IF;
END $$;
