-- Runs once, only on first container initialization (empty data volume)
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;   -- fuzzy text search, useful for RAID/Action description matching
