-- seed/seed_endpoints.sql
-- Insert 8 realistic API endpoints

INSERT INTO endpoints (id, method, path, default_limit)
VALUES
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b11', 'GET', '/api/v1/users', 50),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 'POST', '/api/v1/auth/login', 10),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b33', 'GET', '/api/v1/products', 500),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b44', 'POST', '/api/v1/orders', 100),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b55', 'GET', '/api/v1/search', 200),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b66', 'DELETE', '/api/v1/users/{id}', 20),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b77', 'POST', '/api/v1/upload', 5),
    ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b88', 'GET', '/api/v1/health', 1000)
ON CONFLICT (method, path) DO UPDATE
SET default_limit = EXCLUDED.default_limit,
    updated_at = now();
