ALTER TABLE walk_sessions
    ADD COLUMN paused_at TIMESTAMP,
    ADD COLUMN total_paused_seconds INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN walk_sessions.paused_at IS
    '현재 일시정지가 시작된 시각';

COMMENT ON COLUMN walk_sessions.total_paused_seconds IS
    '재개까지 확정된 누적 일시정지 시간(초)';
