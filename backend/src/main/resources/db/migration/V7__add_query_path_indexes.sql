-- Keep database indexes aligned with the current repository query paths.
-- These indexes are intentionally focused on high-frequency list, lookup, and cleanup queries.

-- Dog ownership / household access checks
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
    ADD COLUMN IF NOT EXISTS address VARCHAR(100),
    ADD COLUMN IF NOT EXISTS birth_date DATE;

CREATE INDEX IF NOT EXISTS idx_dogs_user_id
    ON dogs (user_id);

CREATE INDEX IF NOT EXISTS idx_dogs_birth_month_day
    ON dogs ((EXTRACT(MONTH FROM birth_date)), (EXTRACT(DAY FROM birth_date)))
    WHERE birth_date IS NOT NULL;

-- Social account management
CREATE INDEX IF NOT EXISTS idx_user_auth_user_id
    ON user_auth (user_id);

ALTER TABLE oauth2_login_codes
    ALTER COLUMN code_hash TYPE VARCHAR(64);

-- Walk history, active-session lookup, public route listing, and old route compression
ALTER TABLE walk_sessions
    ADD COLUMN IF NOT EXISTS route_geo_json TEXT;

CREATE INDEX IF NOT EXISTS idx_walk_sessions_user_started
    ON walk_sessions (user_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_walk_sessions_user_status
    ON walk_sessions (user_id, status);

CREATE INDEX IF NOT EXISTS idx_walk_sessions_public_status_started
    ON walk_sessions (is_public, status, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_walk_sessions_status_started
    ON walk_sessions (status, started_at);

-- Many-to-many walk session dog joins
CREATE TABLE IF NOT EXISTS walk_session_dogs (
    session_id BIGINT NOT NULL REFERENCES walk_sessions (id) ON DELETE CASCADE,
    dog_id     BIGINT NOT NULL REFERENCES dogs (id) ON DELETE CASCADE,
    PRIMARY KEY (session_id, dog_id)
);

CREATE INDEX IF NOT EXISTS idx_walk_session_dogs_session_dog
    ON walk_session_dogs (session_id, dog_id);

CREATE INDEX IF NOT EXISTS idx_walk_session_dogs_dog_session
    ON walk_session_dogs (dog_id, session_id);

-- Entity schema alignment for clean Flyway-managed databases
ALTER TABLE dog_favorites
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE TABLE IF NOT EXISTS dog_warnings (
    dog_id  BIGINT      NOT NULL REFERENCES dogs (id) ON DELETE CASCADE,
    warning VARCHAR(20) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_dog_warnings_dog_id
    ON dog_warnings (dog_id);

ALTER TABLE push_settings
    ADD COLUMN IF NOT EXISTS weather_alert_minute INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS birthday_alert_enabled BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS health_checkup_alert_enabled BOOLEAN NOT NULL DEFAULT true;

-- Recent live-location lookup for nearby walk pings
CREATE INDEX IF NOT EXISTS idx_walk_locations_updated_at
    ON walk_locations (updated_at);

-- Ping cooldown and cleanup lookups from both session directions
CREATE INDEX IF NOT EXISTS idx_walk_ping_logs_session_a_pinged
    ON walk_ping_logs (session_a_id, pinged_at);

CREATE INDEX IF NOT EXISTS idx_walk_ping_logs_session_b_pinged
    ON walk_ping_logs (session_b_id, pinged_at);

-- Public route interaction lookups by the current user
CREATE INDEX IF NOT EXISTS idx_walk_route_likes_user_session
    ON walk_route_likes (user_id, session_id);

CREATE INDEX IF NOT EXISTS idx_walk_route_bookmarks_user_session
    ON walk_route_bookmarks (user_id, session_id);

-- Place vote aggregation
CREATE INDEX IF NOT EXISTS idx_place_votes_place_vote_type
    ON place_votes (place_id, vote_type);

-- Community feed and linked sighting lookups
CREATE INDEX IF NOT EXISTS idx_community_posts_created_at
    ON community_posts (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_community_posts_type_created_at
    ON community_posts (type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_community_posts_related_post_created
    ON community_posts (related_post_id, created_at DESC);
