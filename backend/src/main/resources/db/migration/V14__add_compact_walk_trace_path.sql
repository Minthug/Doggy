ALTER TABLE walk_sessions
    ADD COLUMN trace_path_data TEXT;

COMMENT ON COLUMN walk_sessions.trace_path_data IS
    'GPS를 제거한 v1 정규화 델타 경로. Flutter CustomPainter 장기 보관용';
