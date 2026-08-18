CREATE TABLE IF NOT EXISTS marking_spots (
    id          BIGSERIAL PRIMARY KEY,
    lat         DOUBLE PRECISION NOT NULL,
    lng         DOUBLE PRECISION NOT NULL,
    grid_key    VARCHAR(50)      NOT NULL UNIQUE,
    visit_count INTEGER          NOT NULL DEFAULT 0,
    last_visited_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ      NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ      NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_marking_spots_last_visited ON marking_spots (last_visited_at DESC);

CREATE TABLE IF NOT EXISTS marking_spot_visits (
    id          BIGSERIAL PRIMARY KEY,
    spot_id     BIGINT      NOT NULL REFERENCES marking_spots (id) ON DELETE CASCADE,
    session_id  BIGINT      NOT NULL REFERENCES walk_sessions (id) ON DELETE CASCADE,
    dog_id      BIGINT      NOT NULL REFERENCES dogs (id) ON DELETE CASCADE,
    user_id     BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    visited_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_marking_spot_visit UNIQUE (spot_id, session_id, dog_id)
);

CREATE INDEX IF NOT EXISTS idx_marking_spot_visits_spot_created ON marking_spot_visits (spot_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_marking_spot_visits_session_created ON marking_spot_visits (session_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_marking_spot_visits_dog_created ON marking_spot_visits (dog_id, created_at DESC);
