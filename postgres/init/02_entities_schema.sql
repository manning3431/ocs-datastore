-- =====================================================================
-- 02_entities_schema.sql
-- Core entity, relationship, and actor tables.
-- =====================================================================

-- ---------------------------------------------------------------------
-- entities.entity — generic node for programme / value_chain / workstream / project
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entities.entity (
    entity_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type_id      SMALLINT NOT NULL REFERENCES entities.entity_type(entity_type_id),
    entity_name         VARCHAR(255) NOT NULL,
    entity_slug         VARCHAR(255), -- matches slugify_key() output, used for nav/URL lookups
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,  -- soft delete
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (entity_type_id, entity_name)
);

CREATE INDEX IF NOT EXISTS idx_entity_type ON entities.entity(entity_type_id);
CREATE INDEX IF NOT EXISTS idx_entity_active ON entities.entity(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_entity_name_trgm ON entities.entity USING gin (entity_name gin_trgm_ops);


INSERT INTO entities.entity (entity_type_id, entity_name, is_active) 
VALUES
(2, 'Safety', True),
(2, 'People', True),
(2, 'Tech & Ops', True),
(2, 'Customer', True),
(2, 'Environment', True);

-- ---------------------------------------------------------------------
-- entities.entity_relationships — directional links between entities
-- (e.g. programme CONTAINS project, project BELONGS_TO value_chain)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entities.entity_relationships (
    entity_relationship_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_entity_id        UUID NOT NULL REFERENCES entities.entity(entity_id) ON DELETE CASCADE,
    child_entity_id         UUID NOT NULL REFERENCES entities.entity(entity_id) ON DELETE CASCADE,
    relationship_type_id    SMALLINT NOT NULL REFERENCES entities.relationship_type(relationship_type_id),
    effective_from          DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to            DATE, -- NULL = still in effect
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (parent_entity_id <> child_entity_id),
    UNIQUE (parent_entity_id, child_entity_id, relationship_type_id, effective_from)
);

CREATE INDEX IF NOT EXISTS idx_relationships_parent ON entities.entity_relationships(parent_entity_id);
CREATE INDEX IF NOT EXISTS idx_relationships_child ON entities.entity_relationships(child_entity_id);
CREATE INDEX IF NOT EXISTS idx_relationships_active ON entities.entity_relationships(is_active) WHERE is_active = TRUE;

-- ---------------------------------------------------------------------
-- entities.actors — all people (owners, sponsors, contributors)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entities.actors (
    actor_id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name           VARCHAR(255) NOT NULL,
    last_name            VARCHAR(255) NOT NULL,
    email                VARCHAR(255) UNIQUE,
    company              VARCHAR(255),
    is_active            BOOLEAN NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_actors_first_name ON entities.actors(first_name);
CREATE INDEX IF NOT EXISTS idx_actors_last_name ON entities.actors(last_name);
-- ---------------------------------------------------------------------
-- entities.entity_actors — junction: which actor holds which role on which entity
-- Includes date range so role history is preserved, not overwritten.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entities.entity_actors (
    entity_actor_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id             UUID NOT NULL REFERENCES entities.entity(entity_id) ON DELETE CASCADE,
    actor_id              UUID NOT NULL REFERENCES entities.actors(actor_id) ON DELETE CASCADE,
    role_id               SMALLINT NOT NULL REFERENCES entities.role(role_id),
    start_date            DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date              DATE, -- NULL = current holder of this role
    is_active             BOOLEAN NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (entity_id, actor_id, role_id, start_date)
);

CREATE INDEX IF NOT EXISTS idx_entity_actors_entity ON entities.entity_actors(entity_id);
CREATE INDEX IF NOT EXISTS idx_entity_actors_actor ON entities.entity_actors(actor_id);
CREATE INDEX IF NOT EXISTS idx_entity_actors_current ON entities.entity_actors(entity_id, role_id) WHERE end_date IS NULL;
