-- Keep the household that owned a walk at creation time immutable.
-- Sharing must not change when a dog or member later moves households.
ALTER TABLE walk_sessions
    ADD COLUMN household_id BIGINT;

ALTER TABLE walk_sessions
    ADD CONSTRAINT fk_walk_sessions_household
        FOREIGN KEY (household_id) REFERENCES households (id) ON DELETE SET NULL;

-- Privacy-first backfill: only sessions created after the owner's current
-- household join time are safe to associate. Older/ambiguous rows stay owner-only.
UPDATE walk_sessions ws
SET household_id = hm.household_id
FROM household_members hm
WHERE hm.user_id = ws.user_id
  AND ws.started_at >= hm.joined_at;

CREATE INDEX idx_walk_sessions_household_status_started
    ON walk_sessions (household_id, status, started_at DESC);
