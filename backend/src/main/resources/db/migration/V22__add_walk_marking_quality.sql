ALTER TABLE walk_sessions
    ADD COLUMN route_fingerprint VARCHAR(64),
    ADD COLUMN marking_eligible BOOLEAN NOT NULL DEFAULT TRUE;

CREATE INDEX idx_walk_sessions_user_route_fingerprint
    ON walk_sessions (user_id, route_fingerprint)
    WHERE route_fingerprint IS NOT NULL;
