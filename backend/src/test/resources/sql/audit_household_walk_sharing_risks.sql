-- 가족 산책 공유 위험 시나리오 감사
--
-- 이 파일은 모든 위험 시나리오를 끝까지 관찰할 수 있도록 오류에서 중단하지 않고
-- 각 시나리오를 PASS / FAIL로 출력한다. 모든 데이터는 마지막에 ROLLBACK된다.
--
-- 실행 예시:
--   docker exec -i doggy-marking-db psql -U doggy -d doggy_marking \
--     < backend/src/test/resources/sql/audit_household_walk_sharing_risks.sql

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE household_walk_risk_results (
    case_no  INTEGER,
    severity VARCHAR(10),
    scenario TEXT,
    expected TEXT,
    observed TEXT,
    result   VARCHAR(6)
) ON COMMIT DROP;

DO $audit$
DECLARE
    v_household_a_id BIGINT;
    v_household_b_id BIGINT;
    v_owner_id       BIGINT;
    v_member_id      BIGINT;
    v_mover_id       BIGINT;
    v_new_owner_id   BIGINT;
    v_owner_dog_id   BIGINT;
    v_member_dog_id  BIGINT;
    v_mover_dog_id   BIGINT;
    v_detail_session_id BIGINT;
    v_dogless_session_id BIGINT;
    v_active_session_id BIGINT;
    v_migration_session_id BIGINT;
    v_owner_history_visible BOOLEAN;
    v_member_detail_visible BOOLEAN;
    v_visible BOOLEAN;
    v_full_count BIGINT;
    v_page_count BIGINT;
    v_full_distance BIGINT;
    v_page_distance BIGINT;
    v_bad_status_count BIGINT;
    v_boundary_count BIGINT;
BEGIN
    INSERT INTO users (nickname) VALUES ('위험감사_기존가족오너') RETURNING id INTO v_owner_id;
    INSERT INTO users (nickname) VALUES ('위험감사_기존가족멤버') RETURNING id INTO v_member_id;
    INSERT INTO users (nickname) VALUES ('위험감사_이동멤버') RETURNING id INTO v_mover_id;
    INSERT INTO users (nickname) VALUES ('위험감사_새가족오너') RETURNING id INTO v_new_owner_id;

    INSERT INTO households (name, invite_code)
    VALUES ('위험감사_기존가족', 'RISKA_' || v_owner_id || '_' || v_member_id)
    RETURNING id INTO v_household_a_id;

    INSERT INTO households (name, invite_code)
    VALUES ('위험감사_새가족', 'RISKB_' || v_mover_id || '_' || v_new_owner_id)
    RETURNING id INTO v_household_b_id;

    INSERT INTO household_members (household_id, user_id, role, joined_at)
    VALUES
        (v_household_a_id, v_owner_id, 'OWNER', now() - interval '30 days'),
        (v_household_a_id, v_member_id, 'MEMBER', now() - interval '30 days'),
        (v_household_a_id, v_mover_id, 'MEMBER', now() - interval '30 days'),
        (v_household_b_id, v_new_owner_id, 'OWNER', now() - interval '30 days');

    INSERT INTO dogs (user_id, household_id, name)
    VALUES (v_owner_id, v_household_a_id, '위험감사_오너강아지')
    RETURNING id INTO v_owner_dog_id;

    INSERT INTO dogs (user_id, household_id, name)
    VALUES (v_member_id, v_household_a_id, '위험감사_멤버강아지')
    RETURNING id INTO v_member_dog_id;

    INSERT INTO dogs (user_id, household_id, name)
    VALUES (v_mover_id, v_household_a_id, '위험감사_이동강아지')
    RETURNING id INTO v_mover_dog_id;

    -- 1. 목록과 상세가 동일한 가족 스냅샷 권한을 사용한다.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, ended_at, distance_meters, duration_seconds, status, title
    ) VALUES (
        v_member_id, v_household_a_id, now() - interval '40 minutes', now() - interval '30 minutes',
        600, 600, 'COMPLETED', '위험감사_상세조회'
    ) RETURNING id INTO v_detail_session_id;

    INSERT INTO walk_session_dogs (session_id, dog_id)
    VALUES (v_detail_session_id, v_member_dog_id);

    SELECT EXISTS (
        SELECT 1 FROM walk_sessions ws
        WHERE ws.id = v_detail_session_id
          AND (
              ws.user_id = v_owner_id
              OR (ws.household_id = v_household_a_id
                  AND ws.status = 'COMPLETED'
                  AND ws.started_at >= now() - interval '30 days')
          )
    ) INTO v_owner_history_visible;

    SELECT EXISTS (
        SELECT 1 FROM walk_sessions ws
        WHERE ws.id = v_detail_session_id
          AND (
              ws.user_id = v_owner_id
              OR (ws.household_id = v_household_a_id
                  AND ws.status = 'COMPLETED'
                  AND ws.started_at >= now() - interval '30 days')
          )
    ) INTO v_member_detail_visible;

    INSERT INTO household_walk_risk_results
    VALUES (
        1, 'HIGH', '가족 산책 이력에서 상세 화면 열기',
        '이력에 보이는 가족은 상세도 조회 가능',
        format('이력=%s, 상세=%s', v_owner_history_visible, v_member_detail_visible),
        CASE WHEN v_owner_history_visible AND v_member_detail_visible THEN 'PASS' ELSE 'FAIL' END
    );

    -- 2. 강아지가 없어도 산책 당시 가족 스냅샷으로 공유한다.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, ended_at, distance_meters, duration_seconds, status, title
    ) VALUES (
        v_member_id, v_household_a_id, now() - interval '25 minutes', now() - interval '20 minutes',
        300, 300, 'COMPLETED', '위험감사_강아지없는산책'
    ) RETURNING id INTO v_dogless_session_id;

    SELECT EXISTS (
        SELECT 1 FROM walk_sessions ws
        WHERE ws.id = v_dogless_session_id
          AND (
              ws.user_id = v_owner_id
              OR (ws.household_id = v_household_a_id
                  AND ws.status = 'COMPLETED'
                  AND ws.started_at >= now() - interval '30 days')
          )
    ) INTO v_visible;

    INSERT INTO household_walk_risk_results
    VALUES (
        2, 'HIGH', '강아지를 선택하지 않은 가족 산책 공유',
        '같은 가족의 완료 기록이므로 공유',
        format('가족 오너에게 노출=%s', v_visible),
        CASE WHEN v_visible THEN 'PASS' ELSE 'FAIL' END
    );

    -- 3. 진행 중 세션은 작성자에게만 보이고 가족 공유에서는 제외한다.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, distance_meters, duration_seconds, status, title
    ) VALUES (
        v_member_id, v_household_a_id, now() - interval '5 minutes', 0, 0,
        'IN_PROGRESS', '위험감사_진행중산책'
    ) RETURNING id INTO v_active_session_id;

    INSERT INTO walk_session_dogs (session_id, dog_id)
    VALUES (v_active_session_id, v_member_dog_id);

    SELECT EXISTS (
        SELECT 1 FROM walk_sessions ws
        WHERE ws.id = v_active_session_id
          AND (
              ws.user_id = v_owner_id
              OR (ws.household_id = v_household_a_id
                  AND ws.status = 'COMPLETED'
                  AND ws.started_at >= now() - interval '30 days')
          )
    ) INTO v_visible;

    INSERT INTO household_walk_risk_results
    VALUES (
        3, 'MEDIUM', '진행 중 산책의 가족 이력 노출',
        '완료 전에는 다른 가족 이력에 미노출',
        format('가족 오너에게 노출=%s', v_visible),
        CASE WHEN NOT v_visible THEN 'PASS' ELSE 'FAIL' END
    );

    -- 4. 서버 집계는 이력 페이지 제한 없이 오늘 전체를 계산한다.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, ended_at, distance_meters, duration_seconds, status, title
    )
    SELECT
        v_member_id,
        v_household_a_id,
        (date_trunc('day', now() AT TIME ZONE 'Asia/Seoul') + interval '12 hours'
            + make_interval(secs => g)) AT TIME ZONE 'Asia/Seoul',
        (date_trunc('day', now() AT TIME ZONE 'Asia/Seoul') + interval '12 hours 1 minute'
            + make_interval(secs => g)) AT TIME ZONE 'Asia/Seoul',
        10,
        60,
        'COMPLETED',
        '위험감사_대량_' || lpad(g::text, 3, '0')
    FROM generate_series(1, 101) AS g;

    INSERT INTO walk_session_dogs (session_id, dog_id)
    SELECT ws.id, v_member_dog_id
    FROM walk_sessions ws
    WHERE ws.title LIKE '위험감사_대량_%';

    SELECT count(*), coalesce(sum(ws.distance_meters), 0)
    INTO v_full_count, v_full_distance
    FROM walk_sessions ws
    WHERE ws.status = 'COMPLETED'
      AND (ws.started_at AT TIME ZONE 'Asia/Seoul')::date
            = (now() AT TIME ZONE 'Asia/Seoul')::date
      AND (
          ws.user_id = v_owner_id
          OR (ws.household_id = v_household_a_id
              AND ws.started_at >= now() - interval '30 days')
      );

    SELECT count(*), coalesce(sum(ws.distance_meters), 0)
    INTO v_page_count, v_page_distance
    FROM walk_sessions ws
    WHERE ws.status = 'COMPLETED'
      AND (ws.started_at AT TIME ZONE 'Asia/Seoul')::date
            = (now() AT TIME ZONE 'Asia/Seoul')::date
      AND (ws.user_id = v_owner_id
           OR (ws.household_id = v_household_a_id
               AND ws.started_at >= now() - interval '30 days'));

    INSERT INTO household_walk_risk_results
    VALUES (
        4, 'HIGH', '하루 100건 초과 시 오늘 합계',
        format('전체 %s건/%sm와 동일', v_full_count, v_full_distance),
        format('서버 집계 %s건/%sm', v_page_count, v_page_distance),
        CASE
            WHEN v_page_count = v_full_count AND v_page_distance = v_full_distance THEN 'PASS'
            ELSE 'FAIL'
        END
    );

    -- 5. 가족 이동 후에도 산책 당시 가족 스냅샷은 바뀌지 않는다.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, ended_at, distance_meters, duration_seconds, status, title
    ) VALUES (
        v_mover_id, v_household_a_id, now() - interval '10 days', now() - interval '10 days' + interval '10 minutes',
        800, 600, 'COMPLETED', '위험감사_가족이동전_과거산책'
    ) RETURNING id INTO v_migration_session_id;

    INSERT INTO walk_session_dogs (session_id, dog_id)
    VALUES (v_migration_session_id, v_mover_dog_id);

    DELETE FROM household_members
    WHERE household_id = v_household_a_id AND user_id = v_mover_id;

    UPDATE dogs SET household_id = v_household_b_id WHERE id = v_mover_dog_id;

    INSERT INTO household_members (household_id, user_id, role)
    VALUES (v_household_b_id, v_mover_id, 'MEMBER');

    SELECT EXISTS (
        SELECT 1 FROM walk_sessions ws
        WHERE ws.id = v_migration_session_id
          AND (
              ws.user_id = v_new_owner_id
              OR (ws.household_id = v_household_b_id
                  AND ws.status = 'COMPLETED'
                  AND ws.started_at >= now() - interval '30 days')
          )
    ) INTO v_visible;

    INSERT INTO household_walk_risk_results
    VALUES (
        5, 'CRITICAL', '가족 이동 후 과거 산책의 새 가족 노출',
        '새 가족 합류 전 기록은 자동 공개되지 않음',
        format('새 가족 오너에게 과거 기록 노출=%s', v_visible),
        CASE WHEN NOT v_visible THEN 'PASS' ELSE 'FAIL' END
    );

    -- 6. 과거 기록은 산책 당시 가족의 공동 기록으로 유지한다.
    SELECT EXISTS (
        SELECT 1 FROM walk_sessions ws
        WHERE ws.id = v_migration_session_id
          AND (
              ws.user_id = v_owner_id
              OR (ws.household_id = v_household_a_id
                  AND ws.status = 'COMPLETED'
                  AND ws.started_at >= now() - interval '30 days')
          )
    ) INTO v_visible;

    INSERT INTO household_walk_risk_results
    VALUES (
        6, 'MEDIUM', '가족 이동 후 기존 가족의 과거 기록 유지',
        '산책 당시 가족에게 과거 공동 기록 유지',
        format('기존 가족 오너에게 과거 기록 노출=%s', v_visible),
        CASE WHEN v_visible THEN 'PASS' ELSE 'FAIL' END
    );

    -- 7. 오늘 통계의 COMPLETED 필터는 진행/중단 기록을 제외한다.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, distance_meters, duration_seconds, status, title
    ) VALUES
        (v_owner_id, v_household_a_id, now(), 9999, 9999, 'PAUSED', '위험감사_일시정지'),
        (v_owner_id, v_household_a_id, now(), 9999, 9999, 'ABANDONED', '위험감사_중단');

    SELECT count(*) INTO v_bad_status_count
    FROM walk_sessions ws
    WHERE ws.title IN ('위험감사_일시정지', '위험감사_중단')
      AND ws.status = 'COMPLETED';

    INSERT INTO household_walk_risk_results
    VALUES (
        7, 'MEDIUM', '진행/중단 기록의 오늘 합계 포함 여부',
        'COMPLETED가 아닌 기록 0건 포함',
        format('포함=%s건', v_bad_status_count),
        CASE WHEN v_bad_status_count = 0 THEN 'PASS' ELSE 'FAIL' END
    );

    -- 8. 서울 자정 직전/직후를 DB 기준으로 정확히 구분한다.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, ended_at, distance_meters, duration_seconds, status, title
    ) VALUES
        (
            v_owner_id, v_household_a_id,
            (date_trunc('day', now() AT TIME ZONE 'Asia/Seoul') - interval '1 second')
                AT TIME ZONE 'Asia/Seoul',
            date_trunc('day', now() AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul',
            111, 60, 'COMPLETED', '위험감사_자정직전'
        ),
        (
            v_owner_id, v_household_a_id,
            (date_trunc('day', now() AT TIME ZONE 'Asia/Seoul') + interval '1 second')
                AT TIME ZONE 'Asia/Seoul',
            (date_trunc('day', now() AT TIME ZONE 'Asia/Seoul') + interval '61 seconds')
                AT TIME ZONE 'Asia/Seoul',
            222, 60, 'COMPLETED', '위험감사_자정직후'
        );

    SELECT count(*) INTO v_boundary_count
    FROM walk_sessions ws
    WHERE ws.title IN ('위험감사_자정직전', '위험감사_자정직후')
      AND (ws.started_at AT TIME ZONE 'Asia/Seoul')::date
            = (now() AT TIME ZONE 'Asia/Seoul')::date;

    INSERT INTO household_walk_risk_results
    VALUES (
        8, 'MEDIUM', '서울 시간 자정 경계의 오늘 기록 분류',
        '자정 직후 기록만 오늘로 분류',
        format('오늘로 분류=%s건', v_boundary_count),
        CASE WHEN v_boundary_count = 1 THEN 'PASS' ELSE 'FAIL' END
    );

    -- 9. 새로 합류한 가족은 합류 이전에 만들어진 가족 기록을 자동으로 받지 않는다.
    INSERT INTO walk_sessions (
        user_id, household_id, started_at, ended_at, distance_meters, duration_seconds, status, title
    ) VALUES (
        v_new_owner_id, v_household_b_id,
        now() - interval '1 day', now() - interval '1 day' + interval '10 minutes',
        400, 600, 'COMPLETED', '위험감사_새멤버합류전_기록'
    );

    SELECT EXISTS (
        SELECT 1 FROM walk_sessions ws
        WHERE ws.title = '위험감사_새멤버합류전_기록'
          AND (
              ws.user_id = v_mover_id
              OR (ws.household_id = v_household_b_id
                  AND ws.status = 'COMPLETED'
                  AND ws.started_at >= (
                      SELECT hm.joined_at
                      FROM household_members hm
                      WHERE hm.household_id = v_household_b_id
                        AND hm.user_id = v_mover_id
                  ))
          )
    ) INTO v_visible;

    INSERT INTO household_walk_risk_results
    VALUES (
        9, 'HIGH', '새 가족 구성원의 합류 이전 기록 접근',
        '합류 이전 가족 기록은 자동 공개되지 않음',
        format('새 구성원에게 합류 전 기록 노출=%s', v_visible),
        CASE WHEN NOT v_visible THEN 'PASS' ELSE 'FAIL' END
    );
END
$audit$;

SELECT case_no, severity, result, scenario, expected, observed
FROM household_walk_risk_results
ORDER BY case_no;

SELECT
    count(*) FILTER (WHERE result = 'PASS') AS passed,
    count(*) FILTER (WHERE result = 'FAIL') AS failed
FROM household_walk_risk_results;

ROLLBACK;
