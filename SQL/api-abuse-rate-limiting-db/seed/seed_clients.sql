-- seed/seed_clients.sql

-- Insert 6 clients with realistic data
INSERT INTO clients (id, name, plan_id, is_blocked, blocked_reason)
VALUES
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c11', 'Acme Corp', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', false, null),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c22', 'TechStartup Ltd', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', false, null),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33', 'Solo Developer', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', false, null),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c44', 'SpamBot Inc', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', true, 'Repeated API abuse'),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c55', 'ScraperService', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', false, null),
    ('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c66', 'BruteForcer', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', false, null)
ON CONFLICT (id) DO UPDATE
SET is_blocked = EXCLUDED.is_blocked,
    blocked_reason = EXCLUDED.blocked_reason,
    updated_at = now();

-- INSERT api_keys
INSERT INTO api_keys (id, client_id, key_prefix, key_hash, is_active)
VALUES
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d11', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c11', 'sk_acme1', encode(sha256('acme_key_1'), 'hex'), true),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d22', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c22', 'sk_tech1', encode(sha256('tech_key_1'), 'hex'), true),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d33', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33', 'sk_solo1', encode(sha256('solo_key_1'), 'hex'), true),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c44', 'sk_spam1', encode(sha256('spam_key_1'), 'hex'), true),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d45', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c44', 'sk_spam2', encode(sha256('spam_key_2'), 'hex'), false),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d55', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c55', 'sk_scra1', encode(sha256('scraper_key_1'), 'hex'), true),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d56', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c55', 'sk_scra2', encode(sha256('scraper_key_2'), 'hex'), false),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d66', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c66', 'sk_brut1', encode(sha256('brute_key_1'), 'hex'), true),
    ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d67', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c66', 'sk_brut2', encode(sha256('brute_key_2'), 'hex'), false)
ON CONFLICT (id) DO NOTHING;

-- INSERT rate_limit_rules
INSERT INTO rate_limit_rules (id, rule_type, target_type, target_id, limit_amount, window_seconds, priority)
VALUES
    -- Global rule: token_bucket, 1000 req/60s (low priority=0)
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380e11', 'token_bucket', 'global', null, 1000, 60, 0),
    -- Rule for POST /auth/login: fixed_window, 10 req/60s (priority=5)
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380e22', 'fixed_window', 'endpoint', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 10, 60, 5),
    -- Override for SpamBot Inc: token_bucket, 1 req/60s (priority=10) - heavily throttled
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380e33', 'token_bucket', 'client', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c44', 1, 60, 10),
    -- Override for Acme Corp: token_bucket, 5000 req/60s (priority=10) - enterprise override
    ('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380e44', 'token_bucket', 'client', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c11', 5000, 60, 10)
ON CONFLICT (id) DO NOTHING;

-- INSERT into request_logs
-- 200 rows of normal traffic for Acme Corp
INSERT INTO request_logs (id, client_id, endpoint_id, ip_address, status_code, created_at)
SELECT
    gen_random_uuid(),
    'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c11',
    'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11',
    '10.0.0.1',
    CASE WHEN random() < 0.8 THEN 200 ELSE 201 END,
    now() - (random() * interval '24 hours')
FROM generate_series(1, 200);

-- 150 rows for ScraperService all hitting GET /api/v1/products rapidly
INSERT INTO request_logs (id, client_id, endpoint_id, ip_address, status_code, created_at)
SELECT
    gen_random_uuid(),
    'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c55',
    'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b33',
    '192.168.1.100',
    CASE WHEN random() < 0.9 THEN 200 ELSE 429 END,
    now() - (random() * interval '5 minutes')
FROM generate_series(1, 150);

-- 200 rows for BruteForcer all hitting POST /api/v1/auth/login
INSERT INTO request_logs (id, client_id, endpoint_id, ip_address, status_code, created_at)
SELECT
    gen_random_uuid(),
    'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c66',
    'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22',
    '192.168.100.50',
    CASE WHEN random() < 0.95 THEN 401 ELSE 429 END,
    now() - (random() * interval '24 hours')
FROM generate_series(1, 200);

-- 50 rows of normal for Solo Developer
INSERT INTO request_logs (id, client_id, endpoint_id, ip_address, status_code, created_at)
SELECT
    gen_random_uuid(),
    'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33',
    'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b55',
    '172.16.0.10',
    200,
    now() - (random() * interval '24 hours')
FROM generate_series(1, 50);

-- INSERT abuse_flags
INSERT INTO abuse_flags (id, client_id, severity, description, is_resolved)
VALUES
    (gen_random_uuid(), 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c55', 'high', 'Rapid requests to /products', false),
    (gen_random_uuid(), 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c55', 'high', 'Data scraping behavior detected', false),
    (gen_random_uuid(), 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c66', 'medium', 'Multiple 401s on login', true),
    (gen_random_uuid(), 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c66', 'critical', 'Brute force attack on login', false),
    (gen_random_uuid(), 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c66', 'critical', 'Continued brute force attempts', false)
ON CONFLICT DO NOTHING;

-- INSERT into blocklist
INSERT INTO blocklist (id, block_type, block_value, reason, expires_at)
VALUES
    (gen_random_uuid(), 'client_id', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c44', 'Spam behavior', now() + interval '30 days'),
    (gen_random_uuid(), 'ip_address', '192.168.100.50', 'Brute force source IP', now() + interval '7 days')
ON CONFLICT DO NOTHING;
