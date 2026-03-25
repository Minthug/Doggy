-- PostGIS 확장
CREATE EXTENSION IF NOT EXISTS postgis;

-- users
CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    nickname      VARCHAR(50)  NOT NULL,
    profile_image VARCHAR(500),
    fcm_token     VARCHAR(500),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- user_auth
CREATE TABLE user_auth (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    auth_type     VARCHAR(20)  NOT NULL, -- LOCAL / KAKAO / GOOGLE / APPLE
    email         VARCHAR(255),
    password_hash VARCHAR(255),
    provider_id   VARCHAR(255),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_auth_type_provider UNIQUE (auth_type, provider_id),
    CONSTRAINT uq_auth_type_email    UNIQUE (auth_type, email)
);

-- dogs
CREATE TABLE dogs (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name          VARCHAR(50)  NOT NULL,
    breed         VARCHAR(100),
    birth_date    DATE,
    weight_kg     DECIMAL(4, 1),
    gender        VARCHAR(10),              -- MALE / FEMALE
    is_neutered   BOOLEAN      NOT NULL DEFAULT false,
    profile_image VARCHAR(500),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- walk_sessions
CREATE TABLE walk_sessions (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    started_at       TIMESTAMPTZ NOT NULL,
    ended_at         TIMESTAMPTZ,
    distance_meters  INTEGER     NOT NULL DEFAULT 0,
    duration_seconds INTEGER     NOT NULL DEFAULT 0,
    status           VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS', -- IN_PROGRESS / COMPLETED / PAUSED
    is_public        BOOLEAN     NOT NULL DEFAULT false,          -- 경로 공개 여부
    title            VARCHAR(100),                                -- 공개 경로 제목
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- walk_points
CREATE TABLE walk_points (
    id           BIGSERIAL PRIMARY KEY,
    session_id   BIGINT          NOT NULL REFERENCES walk_sessions (id) ON DELETE CASCADE,
    recorded_at  TIMESTAMPTZ     NOT NULL,
    lat          DOUBLE PRECISION NOT NULL,
    lng          DOUBLE PRECISION NOT NULL,
    accuracy     FLOAT
);

CREATE INDEX idx_walk_points_session_time ON walk_points (session_id, recorded_at);

-- places
CREATE TABLE places (
    id           BIGSERIAL PRIMARY KEY,
    name         VARCHAR(200) NOT NULL,
    category     VARCHAR(50)  NOT NULL, -- HOSPITAL / PARK / CAFE / PET_SHOP / PET_HOTEL
    address      VARCHAR(500),
    lat          DOUBLE PRECISION NOT NULL,
    lng          DOUBLE PRECISION NOT NULL,
    location     GEOMETRY(POINT, 4326) NOT NULL,
    phone        VARCHAR(20),
    is_open24h   BOOLEAN      NOT NULL DEFAULT false,
    is_emergency BOOLEAN      NOT NULL DEFAULT false,
    allows_dogs  BOOLEAN      NOT NULL DEFAULT true,
    source       VARCHAR(20)  NOT NULL, -- PUBLIC_DATA / KAKAO / USER
    is_verified  BOOLEAN      NOT NULL DEFAULT false,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_places_location ON places USING GIST (location);
CREATE INDEX idx_places_category ON places (category);

-- place_votes
CREATE TABLE place_votes (
    id         BIGSERIAL PRIMARY KEY,
    place_id   BIGINT      NOT NULL REFERENCES places (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vote_type  VARCHAR(20) NOT NULL, -- HELPFUL / NOT_HELPFUL
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_place_vote UNIQUE (place_id, user_id)
);

-- walk_route_likes (경로 좋아요 - 인기 경로 추천 기반)
CREATE TABLE walk_route_likes (
    id         BIGSERIAL PRIMARY KEY,
    session_id BIGINT      NOT NULL REFERENCES walk_sessions (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_route_like UNIQUE (session_id, user_id)
);

-- walk_route_bookmarks (경로 저장 - 사용자 취향 파악 기반)
CREATE TABLE walk_route_bookmarks (
    id         BIGSERIAL PRIMARY KEY,
    session_id BIGINT      NOT NULL REFERENCES walk_sessions (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_route_bookmark UNIQUE (session_id, user_id)
);

-- walk_route_tags (경로 태그 - 속성 기반 필터링 기반)
-- 태그 종류: SHADY(그늘많음), QUIET(조용함), PARK(공원경유), RIVERSIDE(강변),
--           HILL(언덕있음), FLAT(평지), DOG_FRIENDLY(반려견친화), WIDE_ROAD(넓은길)
CREATE TABLE walk_route_tags (
    session_id BIGINT      NOT NULL REFERENCES walk_sessions (id) ON DELETE CASCADE,
    tag        VARCHAR(30) NOT NULL,
    PRIMARY KEY (session_id, tag)
);

-- push_settings
CREATE TABLE push_settings (
    id                      BIGSERIAL PRIMARY KEY,
    user_id                 BIGINT  NOT NULL REFERENCES users (id) ON DELETE CASCADE UNIQUE,
    walk_reminder_enabled   BOOLEAN NOT NULL DEFAULT true,
    reminder_interval_hours INTEGER NOT NULL DEFAULT 8,
    weather_alert_enabled   BOOLEAN NOT NULL DEFAULT true,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);
