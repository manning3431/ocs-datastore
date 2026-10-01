-- =====================================================================
-- 01_schemas_and_lookups.sql
-- Creates schemas, extensions, and lookup/reference tables first,
-- since core tables have FK dependencies on them.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE SCHEMA IF NOT EXISTS entities;
CREATE SCHEMA IF NOT EXISTS tasks;
CREATE SCHEMA IF NOT EXISTS admin;

-- ---------------------------------------------------------------------
-- entities.entity_type — lookup, prevents free-text typos on entity.entity_type
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entities.entity_type (
    entity_type_id      SMALLSERIAL PRIMARY KEY,
    type_code           VARCHAR(50) NOT NULL UNIQUE,   -- e.g. 'programme','workstream','project','value_chain'
    type_label          VARCHAR(100) NOT NULL,
    sort_order          SMALLINT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO entities.entity_type (type_code, type_label, sort_order) VALUES
    ('programme',   'Programme',   1),
    ('value_chain', 'Value Chain', 2),
    ('workstream',  'Workstream',  3),
    ('project',     'Project',     4),
    ('members_club', 'Members Club', 5)
ON CONFLICT (type_code) DO NOTHING;

-- ---------------------------------------------------------------------
-- entities.relationship_type — lookup for entity_relationships.relationship_type
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entities.relationship_type (
    relationship_type_id SMALLSERIAL PRIMARY KEY,
    type_code            VARCHAR(50) NOT NULL UNIQUE,  -- e.g. 'contains','belongs_to','depends_on','matrixed_to'
    type_label           VARCHAR(100) NOT NULL,
    is_hierarchical      BOOLEAN NOT NULL DEFAULT TRUE, -- TRUE = parent/child hierarchy, FALSE = peer/cross-link
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO entities.relationship_type (type_code, type_label, is_hierarchical) VALUES
    ('contains',     'Contains',                TRUE),
    ('belongs_to',   'Belongs To',              TRUE),
    ('matrixed_to',  'Matrixed To (cross-link)', FALSE),
    ('depends_on',   'Depends On',              FALSE)
ON CONFLICT (type_code) DO NOTHING;

-- ---------------------------------------------------------------------
-- entities.role — lookup for entity_actors.role_id
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entities.role (
    role_id             SMALLSERIAL PRIMARY KEY,
    role_code           VARCHAR(50) NOT NULL UNIQUE,   -- e.g. 'sponsor','project_manager','opo','delivery_lead'
    role_label          VARCHAR(100) NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO entities.role (role_code, role_label) VALUES
    ('sponsor',         'Sponsor'),
    ('opo',              'Overall Project Owner'),
    ('project_manager',  'Project Manager'),
    ('delivery_lead',    'Delivery Lead'),
    ('workstream_lead',  'Workstream Lead')
ON CONFLICT (role_code) DO NOTHING;

-- ---------------------------------------------------------------------
-- entities.status — shared status lookup (used by entity, task_list, etc.)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entities.status (
    status_id           SMALLSERIAL PRIMARY KEY,
    status_code         VARCHAR(50) NOT NULL UNIQUE,   -- e.g. 'active','closed','on_hold','cancelled'
    status_label        VARCHAR(100) NOT NULL,
    is_terminal         BOOLEAN NOT NULL DEFAULT FALSE, -- TRUE = closed/cancelled/completed
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO entities.status (status_code, status_label, is_terminal) VALUES
    ('active',      'Active',      FALSE),
    ('on_hold',     'On Hold',     FALSE),
    ('completed',   'Completed',   TRUE),
    ('closed',      'Closed',      TRUE),
    ('cancelled',   'Cancelled',   TRUE)
ON CONFLICT (status_code) DO NOTHING;