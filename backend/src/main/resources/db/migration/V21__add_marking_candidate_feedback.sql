CREATE TABLE marking_candidate_feedback (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL REFERENCES walk_sessions (id) ON DELETE CASCADE,
    candidate_key VARCHAR(50) NOT NULL,
    detected_at TIMESTAMPTZ NOT NULL,
    dwell_seconds INTEGER NOT NULL,
    score INTEGER NOT NULL,
    source VARCHAR(10) NOT NULL,
    marked BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_marking_candidate_feedback UNIQUE (session_id, candidate_key)
);
