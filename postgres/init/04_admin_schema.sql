-- =====================================================================
-- 04_admin_schema.sql
-- Data dictionary tables — doubles as human documentation AND the
-- semantic layer AI will query to understand schema meaning.
-- pgvector embedding column lets an LLM do similarity search over
-- field descriptions instead of relying on exact-name matches.
-- =====================================================================

CREATE TABLE IF NOT EXISTS admin.data_dictionary_tables (
    dict_table_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schema_name            VARCHAR(100) NOT NULL,
    table_name             VARCHAR(100) NOT NULL,
    business_context       TEXT NOT NULL,        -- plain-English description of what this table represents
    business_owner         VARCHAR(255),        -- who "owns" this data domain, e.g. PMO Lead
    embedding              vector(1536),          -- OpenAI text-embedding-3-small dimension; adjust if using a different model
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (schema_name, table_name)
);

CREATE TABLE IF NOT EXISTS admin.data_dictionary_fields (
    dict_field_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dict_table_id          UUID NOT NULL REFERENCES admin.data_dictionary_tables(dict_table_id) ON DELETE CASCADE,
    field_name             VARCHAR(100) NOT NULL,
    data_type              VARCHAR(50),         -- Postgres type as documented, e.g. 'UUID', 'NUMERIC(5,4)'
    business_context       TEXT NOT NULL,       -- plain-English meaning, valid values, business rules
    example_value          TEXT,
    is_pii                 BOOLEAN NOT NULL DEFAULT FALSE,  -- flag sensitive fields for AI/export guardrails
    embedding              vector(1536),
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (dict_table_id, field_name)
);

CREATE INDEX IF NOT EXISTS idx_dict_tables_embedding ON admin.data_dictionary_tables
    USING hnsw (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_dict_fields_embedding ON admin.data_dictionary_fields
    USING hnsw (embedding vector_cosine_ops);

-- ---------------------------------------------------------------------
-- Seed the data dictionary with the schema objects created above.
-- Embeddings left NULL — populate via a batch job once an embedding
-- model/API is wired up (e.g. OpenAI, local sentence-transformers).
-- ---------------------------------------------------------------------
INSERT INTO admin.data_dictionary_tables (schema_name, table_name, business_context, business_owner) VALUES
    ('entities', 'entity', 'Generic node representing any programme, value chain, workstream, or project. One row per entity regardless of type; entity_type_id distinguishes them.', 'PMO Lead'),
    ('entities', 'entity_relationships', 'Directional links between entities, e.g. a programme containing a project, or a project belonging to a value chain. Supports both hierarchy and cross-links.', 'PMO Lead'),
    ('entities', 'actors', 'Master list of all people involved across the portfolio (sponsors, PMs, leads, contributors).', 'PMO Lead'),
    ('entities', 'entity_actors', 'Junction table linking actors to entities with a specific role and date range, preserving role history over time.', 'PMO Lead'),
    ('tasks', 'task_list', 'Unified table for schedule tasks, actions, and RAID items (risks, issues, assumptions, dependencies, decisions), each tied to one entity and optionally to a parent task.', 'PMO Lead'),
    ('admin', 'data_dictionary_tables', 'Documents the business meaning of every schema/table in the database. Includes vector embeddings for AI-driven semantic search over schema metadata.', 'Data Governance'),
    ('admin', 'data_dictionary_fields', 'Documents the business meaning of every field within each table. Includes PII flagging and vector embeddings for AI-driven semantic search.', 'Data Governance')
ON CONFLICT (schema_name, table_name) DO NOTHING;
