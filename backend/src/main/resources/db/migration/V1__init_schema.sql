-- PostGIS 확장
CREATE EXTENSION IF NOT EXISTS postgis;

-- users
CREATE TABLE IF NOT EXISTS users (
    id            BIGSERIAL PRIMARY KEY,
    nickname      VARCHAR(50)  NOT NULL,
    profile_image VARCHAR(500),
    fcm_token     VARCHAR(500),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- user_auth
CREATE TABLE IF NOT EXISTS user_auth (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    auth_type     VARCHAR(20)  NOT NULL,
    email         VARCHAR(255),
    password_hash VARCHAR(255),
    provider_id   VARCHAR(255),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_auth_type_provider UNIQUE (auth_type, provider_id),
    CONSTRAINT uq_auth_type_email    UNIQUE (auth_type, email)
);

-- households
CREATE TABLE IF NOT EXISTS households (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL,
    invite_code VARCHAR(20)  NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- household_members
CREATE TABLE IF NOT EXISTS household_members (
    id           BIGSERIAL PRIMARY KEY,
    household_id BIGINT      NOT NULL REFERENCES households (id) ON DELETE CASCADE,
    user_id      BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role         VARCHAR(10) NOT NULL,
    joined_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (household_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_household_members_user_id ON household_members (user_id);

-- dogs
CREATE TABLE IF NOT EXISTS dogs (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    household_id  BIGINT       REFERENCES households (id) ON DELETE SET NULL,
    name          VARCHAR(50)  NOT NULL,
    breed         VARCHAR(100),
    birth_date    DATE,
    weight_kg     DECIMAL(4, 1),
    gender        VARCHAR(10),
    is_neutered   BOOLEAN      NOT NULL DEFAULT false,
    profile_image VARCHAR(500),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- dog_favorites
CREATE TABLE IF NOT EXISTS dog_favorites (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    dog_id     BIGINT NOT NULL REFERENCES dogs (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, dog_id)
);

CREATE INDEX IF NOT EXISTS idx_dog_favorites_user_id ON dog_favorites (user_id);
CREATE INDEX IF NOT EXISTS idx_dog_favorites_dog_id ON dog_favorites (dog_id);

-- walk_sessions
CREATE TABLE IF NOT EXISTS walk_sessions (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    started_at       TIMESTAMPTZ NOT NULL,
    ended_at         TIMESTAMPTZ,
    distance_meters  INTEGER     NOT NULL DEFAULT 0,
    duration_seconds INTEGER     NOT NULL DEFAULT 0,
    status           VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    is_public        BOOLEAN     NOT NULL DEFAULT false,
    title            VARCHAR(100),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- walk_points
CREATE TABLE IF NOT EXISTS walk_points (
    id          BIGSERIAL PRIMARY KEY,
    session_id  BIGINT           NOT NULL REFERENCES walk_sessions (id) ON DELETE CASCADE,
    recorded_at TIMESTAMPTZ      NOT NULL,
    lat         DOUBLE PRECISION NOT NULL,
    lng         DOUBLE PRECISION NOT NULL,
    accuracy    FLOAT
);

CREATE INDEX IF NOT EXISTS idx_walk_points_session_time ON walk_points (session_id, recorded_at);

-- walk_locations (실시간 위치)
CREATE TABLE IF NOT EXISTS walk_locations (
    id              BIGSERIAL PRIMARY KEY,
    walk_session_id BIGINT           NOT NULL UNIQUE REFERENCES walk_sessions (id) ON DELETE CASCADE,
    lat             DOUBLE PRECISION NOT NULL,
    lng             DOUBLE PRECISION NOT NULL,
    updated_at      TIMESTAMP        NOT NULL DEFAULT now()
);

-- walk_ping_logs (근처 강아지 알림 중복 방지)
CREATE TABLE IF NOT EXISTS walk_ping_logs (
    id           BIGSERIAL PRIMARY KEY,
    session_a_id BIGINT    NOT NULL,
    session_b_id BIGINT    NOT NULL,
    pinged_at    TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_walk_ping UNIQUE (session_a_id, session_b_id)
);

CREATE INDEX IF NOT EXISTS idx_walk_ping_logs_session_b_id ON walk_ping_logs (session_b_id);

-- walk_route_likes
CREATE TABLE IF NOT EXISTS walk_route_likes (
    id         BIGSERIAL PRIMARY KEY,
    session_id BIGINT      NOT NULL REFERENCES walk_sessions (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_route_like UNIQUE (session_id, user_id)
);

-- walk_route_bookmarks
CREATE TABLE IF NOT EXISTS walk_route_bookmarks (
    id         BIGSERIAL PRIMARY KEY,
    session_id BIGINT      NOT NULL REFERENCES walk_sessions (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_route_bookmark UNIQUE (session_id, user_id)
);

-- walk_route_tags
CREATE TABLE IF NOT EXISTS walk_route_tags (
    session_id BIGINT      NOT NULL REFERENCES walk_sessions (id) ON DELETE CASCADE,
    tag        VARCHAR(30) NOT NULL,
    PRIMARY KEY (session_id, tag)
);

-- places
CREATE TABLE IF NOT EXISTS places (
    id           BIGSERIAL PRIMARY KEY,
    name         VARCHAR(200) NOT NULL,
    category     VARCHAR(50)  NOT NULL,
    address      VARCHAR(500),
    lat          DOUBLE PRECISION NOT NULL,
    lng          DOUBLE PRECISION NOT NULL,
    location     GEOMETRY(POINT, 4326) NOT NULL,
    phone        VARCHAR(20),
    is_open24h   BOOLEAN      NOT NULL DEFAULT false,
    is_emergency BOOLEAN      NOT NULL DEFAULT false,
    allows_dogs  BOOLEAN      NOT NULL DEFAULT true,
    source       VARCHAR(20)  NOT NULL,
    is_verified  BOOLEAN      NOT NULL DEFAULT false,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_places_location ON places USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_places_category ON places (category);

-- place_votes
CREATE TABLE IF NOT EXISTS place_votes (
    id         BIGSERIAL PRIMARY KEY,
    place_id   BIGINT      NOT NULL REFERENCES places (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vote_type  VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_place_vote UNIQUE (place_id, user_id)
);

-- community_posts
CREATE TABLE IF NOT EXISTS community_posts (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type            VARCHAR(20)  NOT NULL,
    title           VARCHAR(100) NOT NULL,
    content         TEXT         NOT NULL,
    dog_name        VARCHAR(50),
    breed           VARCHAR(100),
    last_seen_area  VARCHAR(200),
    last_seen_at    TIMESTAMPTZ,
    lat             DOUBLE PRECISION,
    lng             DOUBLE PRECISION,
    contact_info    VARCHAR(100),
    related_post_id BIGINT REFERENCES community_posts (id) ON DELETE SET NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'OPEN',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_community_posts_type    ON community_posts (type);
CREATE INDEX IF NOT EXISTS idx_community_posts_created ON community_posts (created_at DESC);

-- push_settings
CREATE TABLE IF NOT EXISTS push_settings (
    id                      BIGSERIAL PRIMARY KEY,
    user_id                 BIGINT  NOT NULL REFERENCES users (id) ON DELETE CASCADE UNIQUE,
    walk_reminder_enabled   BOOLEAN NOT NULL DEFAULT true,
    reminder_interval_hours INTEGER NOT NULL DEFAULT 8,
    weather_alert_enabled   BOOLEAN NOT NULL DEFAULT true,
    weather_alert_hour      INTEGER NOT NULL DEFAULT 7,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);
