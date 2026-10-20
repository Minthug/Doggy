-- 가족 산책 기록 공유 회귀 테스트
--
-- 실행 예시:
--   docker exec -i doggy-marking-db psql -U doggy -d doggy_marking \
--     < backend/src/test/resources/sql/verify_household_walk_sharing.sql
--
-- 모든 더미 데이터는 하나의 트랜잭션에서 만들고 마지막에 ROLLBACK한다.
-- 따라서 성공/실패 여부와 관계없이 테스트 레코드는 실제 DB에 남지 않는다.

\set ON_ERROR_STOP on

BEGIN;

DO $test$
DECLARE
    v_household_id       BIGINT;
    v_owner_id           BIGINT;
    v_member_id          BIGINT;
    v_outsider_id        BIGINT;
    v_owner_dog_id       BIGINT;
    v_member_dog_id      BIGINT;
    v_outsider_dog_id    BIGINT;
    v_owner_session_id   BIGINT;
    v_member_session_id  BIGINT;
    v_outsider_session_id BIGINT;
    v_old_session_id     BIGINT;

    v_owner_ids          BIGINT[];
    v_member_ids         BIGINT[];
    v_owner_count        BIGINT;
    v_member_count       BIGINT;
    v_owner_distance     BIGINT;
    v_member_distance    BIGINT;
    v_owner_duration     BIGINT;
    v_member_duration    BIGINT;
BEGIN
    INSERT INTO users (nickname)
    VALUES ('공유테스트_보호자')
    RETURNING id INTO v_owner_id;

    INSERT INTO users (nickname)
    VALUES ('공유테스트_가족')
    RETURNING id INTO v_member_id;

    INSERT INTO users (nickname)
    VALUES ('공유테스트_외부인')
    RETURNING id INTO v_outsider_id;

    INSERT INTO households (name, invite_code)
    VALUES ('공유테스트_가족', 'DBTEST_' || v_owner_id || '_' || v_member_id)
    RETURNING id INTO v_household_id;

    INSERT INTO household_members (household_id, user_id, role, joined_at)
    VALUES
        (v_household_id, v_owner_id, 'OWNER', now() - interval '30 days'),
        (v_household_id, v_member_id, 'MEMBER', now() - interval '30 days');

    INSERT INTO dogs (user_id, household_id, name)
    VALUES (v_owner_id, v_household_id, '공유테스트_몽이')
    RETURNING id INTO v_owner_dog_id;

    INSERT INTO dogs (user_id, household_id, name)
    VALUES (v_member_id, v_household_id, '공유테스트_콩이')
    RETURNING id INTO v_member_dog_id;

    INSERT INTO dogs (user_id, name)
    VALUES (v_outsider_id, '공유테스트_외부강아지')
    RETURNING id INTO v_outsider_dog_id;

    -- 보호자가 가족의 두 강아지와 함께 걸은 오늘 산책: 1,000m / 10분.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, ended_at, distance_meters, duration_seconds, status, title
    )
    VALUES (
        v_owner_id, v_household_id,
        now() - interval '40 minutes',
        now() - interval '30 minutes',
        1000,
        600,
        'COMPLETED',
        '공유테스트_두마리_동시산책'
    )
    RETURNING id INTO v_owner_session_id;

    INSERT INTO walk_session_dogs (session_id, dog_id)
    VALUES
        (v_owner_session_id, v_owner_dog_id),
        (v_owner_session_id, v_member_dog_id);

    -- 다른 가족 구성원이 만든 오늘 산책: 500m / 5분.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, ended_at, distance_meters, duration_seconds, status, title
    )
    VALUES (
        v_member_id, v_household_id,
        now() - interval '20 minutes',
        now() - interval '15 minutes',
        500,
        300,
        'COMPLETED',
        '공유테스트_가족산책'
    )
    RETURNING id INTO v_member_session_id;

    INSERT INTO walk_session_dogs (session_id, dog_id)
    VALUES (v_member_session_id, v_member_dog_id);

    -- 같은 날짜의 외부 사용자 기록. 가족 합계에 절대 섞이면 안 된다.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, ended_at, distance_meters, duration_seconds, status, title
    )
    VALUES (
        v_outsider_id, NULL,
        now() - interval '25 minutes',
        now() - interval '10 minutes',
        9000,
        9000,
        'COMPLETED',
        '공유테스트_외부산책'
    )
    RETURNING id INTO v_outsider_session_id;

    INSERT INTO walk_session_dogs (session_id, dog_id)
    VALUES (v_outsider_session_id, v_outsider_dog_id);

    -- 전날 기록. 조회 이력에는 보이지만 '오늘의 산책' 합계에서는 제외되어야 한다.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, ended_at, distance_meters, duration_seconds, status, title
    )
    VALUES (
        v_owner_id, v_household_id,
        date_trunc('day', now() AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul'
            - interval '30 minutes',
        date_trunc('day', now() AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul'
            - interval '20 minutes',
        700,
        400,
        'COMPLETED',
        '공유테스트_전날산책'
    )
    RETURNING id INTO v_old_session_id;

    INSERT INTO walk_session_dogs (session_id, dog_id)
    VALUES (v_old_session_id, v_owner_dog_id);

    -- 실제 백엔드의 ownerOrHousehold 조건과 오늘 통계 조건을 그대로 재현한다.
    SELECT
        array_agg(ws.id ORDER BY ws.id),
        count(*),
        coalesce(sum(ws.distance_meters), 0),
        coalesce(sum(ws.duration_seconds), 0)
    INTO
        v_owner_ids,
        v_owner_count,
        v_owner_distance,
        v_owner_duration
    FROM walk_sessions ws
    WHERE ws.status = 'COMPLETED'
      AND (ws.started_at AT TIME ZONE 'Asia/Seoul')::date
            = (now() AT TIME ZONE 'Asia/Seoul')::date
      AND (
          ws.user_id = v_owner_id
          OR (ws.household_id = v_household_id
              AND ws.started_at >= now() - interval '30 days')
      );

    SELECT
        array_agg(ws.id ORDER BY ws.id),
        count(*),
        coalesce(sum(ws.distance_meters), 0),
        coalesce(sum(ws.duration_seconds), 0)
    INTO
        v_member_ids,
        v_member_count,
        v_member_distance,
        v_member_duration
    FROM walk_sessions ws
    WHERE ws.status = 'COMPLETED'
      AND (ws.started_at AT TIME ZONE 'Asia/Seoul')::date
            = (now() AT TIME ZONE 'Asia/Seoul')::date
      AND (
          ws.user_id = v_member_id
          OR (ws.household_id = v_household_id
              AND ws.started_at >= now() - interval '30 days')
      );

    IF v_owner_ids IS DISTINCT FROM v_member_ids THEN
        RAISE EXCEPTION
            '가족 계정 간 오늘 산책 ID 불일치: 보호자 %, 가족 %',
            v_owner_ids, v_member_ids;
    END IF;

    IF v_owner_count <> 2 OR v_member_count <> 2 THEN
        RAISE EXCEPTION
            '오늘 산책 건수 오류: 보호자 %, 가족 %, 기대값 2',
            v_owner_count, v_member_count;
    END IF;

    IF v_owner_distance <> 1500 OR v_member_distance <> 1500 THEN
        RAISE EXCEPTION
            '오늘 거리 합계 오류: 보호자 %m, 가족 %m, 기대값 1500m',
            v_owner_distance, v_member_distance;
    END IF;

    IF v_owner_duration <> 900 OR v_member_duration <> 900 THEN
        RAISE EXCEPTION
            '오늘 시간 합계 오류: 보호자 %초, 가족 %초, 기대값 900초',
            v_owner_duration, v_member_duration;
    END IF;

    IF v_outsider_session_id = ANY(v_owner_ids)
       OR v_outsider_session_id = ANY(v_member_ids) THEN
        RAISE EXCEPTION '외부 사용자 산책이 가족 기록에 포함됨';
    END IF;

    IF v_old_session_id = ANY(v_owner_ids)
       OR v_old_session_id = ANY(v_member_ids) THEN
        RAISE EXCEPTION '전날 산책이 오늘 기록에 포함됨';
    END IF;

    RAISE NOTICE 'PASS: 두 가족 계정의 오늘 산책 ID가 동일함: %', v_owner_ids;
    RAISE NOTICE 'PASS: 오늘 산책 2건, 총 1500m, 총 900초가 동일함';
    RAISE NOTICE 'PASS: 두 마리 동시 산책은 중복 집계되지 않음';
    RAISE NOTICE 'PASS: 외부 사용자 및 전날 기록은 오늘 합계에서 제외됨';
END
$test$;

ROLLBACK;
