ALTER TABLE walk_sessions
    ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN archived_at TIMESTAMPTZ,
    ADD COLUMN trace_image_svg TEXT,
    ADD COLUMN details_purged_at TIMESTAMPTZ;

CREATE INDEX idx_walk_sessions_retention
    ON walk_sessions (status, is_archived, started_at)
    WHERE details_purged_at IS NULL;

CREATE INDEX idx_walk_sessions_archived_started
    ON walk_sessions (household_id, started_at DESC)
    WHERE is_archived = TRUE;
