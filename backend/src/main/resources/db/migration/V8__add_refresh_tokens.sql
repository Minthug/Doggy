CREATE TABLE IF NOT EXISTS refresh_tokens (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_id     VARCHAR(36)  NOT NULL UNIQUE,
    token_hash   VARCHAR(64)  NOT NULL UNIQUE,
    device_id    VARCHAR(128),
    expires_at   TIMESTAMPTZ  NOT NULL,
    last_used_at TIMESTAMPTZ,
    revoked_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_active
    ON refresh_tokens (user_id, revoked_at);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at
    ON refresh_tokens (expires_at);
