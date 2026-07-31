CREATE TABLE IF NOT EXISTS oauth2_login_codes (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    code_hash  CHAR(64)     NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ  NOT NULL,
    used_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_oauth2_login_codes_expires_at
    ON oauth2_login_codes (expires_at);
