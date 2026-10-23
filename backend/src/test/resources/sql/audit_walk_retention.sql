-- 산책 상세 7일 보관 및 압축 흔적길 보관 회귀 테스트
-- 실행 데이터는 마지막에 전부 ROLLBACK된다.

\set ON_ERROR_STOP on

BEGIN;

DO $test$
DECLARE
    v_user_id BIGINT;
    v_recent_id BIGINT;
    v_old_id BIGINT;
    v_archived_id BIGINT;
    v_visible_ids BIGINT[];
    v_total_before BIGINT;
    v_total_after BIGINT;
BEGIN
    INSERT INTO users (nickname) VALUES ('보관정책_테스트') RETURNING id INTO v_user_id;

    INSERT INTO walk_sessions (
        user_id, started_at, ended_at, distance_meters, duration_seconds,
        status, route_geo_json
    ) VALUES (
        v_user_id, now() - interval '2 days', now() - interval '2 days' + interval '20 minutes',
        1000, 1200, 'COMPLETED', '{"type":"LineString","coordinates":[[127.1,37.5],[127.2,37.6]]}'
    ) RETURNING id INTO v_recent_id;

    INSERT INTO walk_sessions (
        user_id, started_at, ended_at, distance_meters, duration_seconds,
        status, route_geo_json
    ) VALUES (
        v_user_id, now() - interval '8 days', now() - interval '8 days' + interval '10 minutes',
        500, 600, 'COMPLETED', '{"type":"LineString","coordinates":[[127.2,37.5],[127.3,37.6]]}'
    ) RETURNING id INTO v_old_id;

    INSERT INTO walk_sessions (
        user_id, started_at, ended_at, distance_meters, duration_seconds,
        status, is_archived, archived_at, trace_path_data, route_geo_json, is_public
    ) VALUES (
        v_user_id, now() - interval '9 days', now() - interval '9 days' + interval '30 minutes',
        1500, 1800, 'COMPLETED', true, now(), 'v1|70,70;860,460',
        '{"type":"LineString","coordinates":[[127.3,37.5],[127.4,37.6]]}', true
    ) RETURNING id INTO v_archived_id;

    INSERT INTO walk_points (session_id, recorded_at, lat, lng)
    VALUES
        (v_old_id, now() - interval '8 days', 37.5, 127.2),
        (v_old_id, now() - interval '8 days' + interval '1 minute', 37.6, 127.3),
        (v_archived_id, now() - interval '9 days', 37.5, 127.3),
        (v_archived_id, now() - interval '9 days' + interval '1 minute', 37.6, 127.4);

    SELECT array_agg(id ORDER BY id) INTO v_visible_ids
    FROM walk_sessions
    WHERE user_id = v_user_id
      AND status <> 'ABANDONED'
      AND (status <> 'COMPLETED' OR started_at >= now() - interval '7 days' OR is_archived = true);

    IF NOT v_recent_id = ANY(v_visible_ids)
       OR v_old_id = ANY(v_visible_ids)
       OR NOT v_archived_id = ANY(v_visible_ids) THEN
        RAISE EXCEPTION '7일 이력 필터 오류: visible=%', v_visible_ids;
    END IF;

    SELECT sum(distance_meters) INTO v_total_before
    FROM walk_sessions WHERE user_id = v_user_id AND status = 'COMPLETED';

    DELETE FROM walk_points WHERE session_id IN (v_old_id, v_archived_id);
    UPDATE walk_sessions
    SET route_geo_json = NULL, details_purged_at = now(), is_public = false, title = NULL
    WHERE id IN (v_old_id, v_archived_id);

    SELECT sum(distance_meters) INTO v_total_after
    FROM walk_sessions WHERE user_id = v_user_id AND status = 'COMPLETED';

    IF v_total_before <> 3000 OR v_total_after <> v_total_before THEN
        RAISE EXCEPTION '상세 삭제 후 통계 보존 실패: before=%, after=%', v_total_before, v_total_after;
    END IF;

    IF EXISTS (SELECT 1 FROM walk_points WHERE session_id IN (v_old_id, v_archived_id)) THEN
        RAISE EXCEPTION '7일 경과 GPS 포인트가 남아 있음';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM walk_sessions
        WHERE id = v_archived_id
          AND trace_path_data IS NOT NULL
          AND route_geo_json IS NULL
          AND details_purged_at IS NOT NULL
          AND is_public = false
    ) THEN
        RAISE EXCEPTION '보관 기록의 흔적길/개인정보 삭제 상태 오류';
    END IF;

    IF EXISTS (
        SELECT 1 FROM walk_sessions
        WHERE id = v_old_id AND (is_archived = true OR trace_path_data IS NOT NULL)
    ) THEN
        RAISE EXCEPTION '미보관 기록에 흔적길 데이터가 생성됨';
    END IF;

    RAISE NOTICE 'PASS: 최근 기록만 기본 이력에 노출됨';
    RAISE NOTICE 'PASS: 7일이 지난 미보관 기록은 숨겨짐';
    RAISE NOTICE 'PASS: 보관 기록은 압축 흔적길만 남고 GPS/GeoJSON/공개 상태가 제거됨';
    RAISE NOTICE 'PASS: 상세 삭제 후에도 3000m 통계 합계가 유지됨';
END
$test$;

ROLLBACK;
