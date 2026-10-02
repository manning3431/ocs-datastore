-- =====================================================================
-- 03_tasks_schema.sql
-- Task list, preserving parent/child schedule structure and
-- baseline-vs-forecast date tracking from the existing Excel model.
-- =====================================================================

CREATE TABLE IF NOT EXISTS tasks.task_type (
    task_type_id         SMALLSERIAL PRIMARY KEY,
    type_code            VARCHAR(50) NOT NULL UNIQUE, -- e.g. 'schedule_task','action','risk','issue','assumption','dependency','decision'
    type_label           VARCHAR(100) NOT NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO tasks.task_type (type_code, type_label) VALUES
    ('schedule_task', 'Schedule Task'),
    ('action',        'Action'),
    ('risk',          'Risk'),
    ('issue',         'Issue'),
    ('assumption',    'Assumption'),
    ('dependency',    'Dependency'),
    ('decision',      'Decision')
ON CONFLICT (type_code) DO NOTHING;

-- ---------------------------------------------------------------------
-- tasks.task_list — unified table for schedule tasks, actions, and RAID items.
-- Every row is tied to exactly one entity (usually a project) via entity_id.
-- Self-referencing parent_task_id preserves the ref/task_id parent-child
-- pattern from the current projectSchedules JS structure.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tasks.task_list (
    task_id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id               UUID NOT NULL REFERENCES entities.entity(entity_id) ON DELETE CASCADE,
    task_type_id            SMALLINT NOT NULL REFERENCES tasks.task_type(task_type_id),
    parent_task_id          UUID REFERENCES tasks.task_list(task_id) ON DELETE CASCADE, -- NULL = top-level/parent task; populated = child task (mirrors old ref/task_id link)
    legacy_task_ref         VARCHAR(50),   -- preserves original Excel task_id e.g. "1.0", "1.1" for traceability
    title                   VARCHAR(500) NOT NULL,
    description             TEXT,
    status_id               SMALLINT NOT NULL REFERENCES entities.status(status_id) DEFAULT 1,
    owner_actor_id          UUID REFERENCES entities.actors(actor_id),
    progress_pct            NUMERIC(5,4) DEFAULT 0.0000,  -- decimal 0.0000-1.0000, matches existing 'progress' field
    baseline_start_date     DATE,
    baseline_end_date       DATE,
    forecast_end_date       DATE,
    actual_completion_date  DATE,
    due_date                DATE, -- used by actions/RAID items rather than schedule tasks
    source_excel_row_idx    INTEGER,  -- 1-based Excel row, retained for legacy traceability only
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (progress_pct >= 0 AND progress_pct <= 1)
);

CREATE INDEX IF NOT EXISTS idx_task_list_entity ON tasks.task_list(entity_id);
CREATE INDEX IF NOT EXISTS idx_task_list_type ON tasks.task_list(task_type_id);
CREATE INDEX IF NOT EXISTS idx_task_list_parent ON tasks.task_list(parent_task_id);
CREATE INDEX IF NOT EXISTS idx_task_list_owner ON tasks.task_list(owner_actor_id);
CREATE INDEX IF NOT EXISTS idx_task_list_status ON tasks.task_list(status_id);
CREATE INDEX IF NOT EXISTS idx_task_list_active ON tasks.task_list(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_task_list_desc_trgm ON tasks.task_list USING gin (description gin_trgm_ops);


CREATE TABLE IF NOT EXISTS tasks.task_comments (
    comment_id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id                 UUID NOT NULL REFERENCES tasks.task_list(task_id) ON DELETE CASCADE,
    comment                 TEXT,
    owner_actor_id          UUID REFERENCES entities.actors(actor_id),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);