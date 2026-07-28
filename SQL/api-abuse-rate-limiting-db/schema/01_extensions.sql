-- 01_extensions.sql

-- Enable extension for generating UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
COMMENT ON EXTENSION "uuid-ossp" IS 'Used for generating universally unique identifiers (UUIDs) for primary keys.';

-- Enable pgcrypto for cryptographic functions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
COMMENT ON EXTENSION "pgcrypto" IS 'Provides cryptographic functions, used for hashing and verifying API keys securely.';

-- Enable btree_gin for GIN indexing on scalar types
CREATE EXTENSION IF NOT EXISTS "btree_gin";
COMMENT ON EXTENSION "btree_gin" IS 'Adds B-tree equivalent functionality to GIN indexes, useful for indexing multi-column configurations or JSONB.';

-- Enable pg_trgm for text similarity search
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
COMMENT ON EXTENSION "pg_trgm" IS 'Provides trigram matching for fast text search and similarity queries, useful for searching client names or endpoint paths.';
