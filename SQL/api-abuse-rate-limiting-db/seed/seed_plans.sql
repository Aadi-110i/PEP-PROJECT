-- seed/seed_plans.sql
-- Insert 4 plans with explicit UUIDs for repeatability

INSERT INTO plans (id, name, requests_per_minute, burst_capacity)
VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'free', 60, 0),
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'starter', 300, 20),
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'pro', 1000, 100),
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'enterprise', 10000, 500)
ON CONFLICT (name) DO UPDATE
SET requests_per_minute = EXCLUDED.requests_per_minute,
    burst_capacity = EXCLUDED.burst_capacity,
    updated_at = now();
