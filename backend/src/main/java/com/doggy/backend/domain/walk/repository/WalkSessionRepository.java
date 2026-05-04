package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.dto.WalkSessionResponse;
import com.doggy.backend.domain.walk.entity.WalkSession;
import com.doggy.backend.domain.walk.entity.WalkSession.Status;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface WalkSessionRepository extends JpaRepository<WalkSession, Long> {

    // routeGeoJson 제외한 경량 프로젝션 — 히스토리 목록 전용 (ABANDONED 제외)
    @Query("""
            SELECT new com.doggy.backend.domain.walk.dto.WalkSessionResponse(
                w.id, w.startedAt, w.endedAt, w.distanceMeters, w.durationSeconds, w.status
            ) FROM WalkSession w
            WHERE w.user.id = :userId AND w.status <> com.doggy.backend.domain.walk.entity.WalkSession.Status.ABANDONED
            ORDER BY w.startedAt DESC
            """)
    List<WalkSessionResponse> findHistoryByUserId(@Param("userId") Long userId, Pageable pageable);

    Optional<WalkSession> findByIdAndUserId(Long id, Long userId);

    Optional<WalkSession> findTopByUserIdOrderByStartedAtDesc(Long userId);

    @Query("SELECT w FROM WalkSession w WHERE w.user.id = :userId AND w.status = :status")
    Optional<WalkSession> findActiveSession(@Param("userId") Long userId, @Param("status") Status status);

    // 공개된 경로 목록 — 반경 내 + 인기순
    @Query(value = """
            SELECT ws.* FROM walk_sessions ws
            WHERE ws.is_public = true AND ws.status = 'COMPLETED'
              AND EXISTS (
                  SELECT 1 FROM walk_points wp
                  WHERE wp.session_id = ws.id
                    AND wp.recorded_at = (SELECT MIN(wp2.recorded_at) FROM walk_points wp2 WHERE wp2.session_id = ws.id)
                    AND (6371000 * acos(
                        LEAST(1.0,
                          cos(radians(:lat)) * cos(radians(wp.lat)) * cos(radians(wp.lng) - radians(:lng))
                          + sin(radians(:lat)) * sin(radians(wp.lat))
                        )
                    )) <= :radiusMeters
              )
            ORDER BY (SELECT COUNT(*) FROM walk_route_likes wrl WHERE wrl.session_id = ws.id) DESC,
                     ws.started_at DESC
            LIMIT :size OFFSET :offset
            """, nativeQuery = true)
    List<WalkSession> findPublicRoutesNearby(
            @Param("lat") double lat,
            @Param("lng") double lng,
            @Param("radiusMeters") double radiusMeters,
            @Param("size") int size,
            @Param("offset") int offset
    );

    // 공개된 경로 목록 — 인기순 (위치 없을 때 폴백)
    @Query(value = """
            SELECT ws.* FROM walk_sessions ws
            WHERE ws.is_public = true AND ws.status = 'COMPLETED'
            ORDER BY (SELECT COUNT(*) FROM walk_route_likes wrl WHERE wrl.session_id = ws.id) DESC,
                     ws.started_at DESC
            LIMIT :size OFFSET :offset
            """, nativeQuery = true)
    List<WalkSession> findPublicRoutesByLikes(
            @Param("size") int size,
            @Param("offset") int offset
    );

    // 압축/삭제 대상: N개월 이전 완료 세션 중 walk_points 남아있는 것
    @Query(value = """
            SELECT ws.* FROM walk_sessions ws
            WHERE ws.status = 'COMPLETED'
              AND ws.started_at < :before
              AND EXISTS (SELECT 1 FROM walk_points wp WHERE wp.session_id = ws.id)
            ORDER BY ws.started_at ASC
            LIMIT :lim
            """, nativeQuery = true)
    List<WalkSession> findSessionsWithPointsBefore(
            @Param("before") LocalDateTime before,
            @Param("lim") int lim);

    // 마지막 산책이 since 이전인 유저 ID 목록 (fcmToken 있는 유저만)
    @Query("""
            SELECT DISTINCT w.user.id FROM WalkSession w
            WHERE w.status = 'COMPLETED'
            AND w.user.fcmToken IS NOT NULL
            AND w.user.id NOT IN (
                SELECT w2.user.id FROM WalkSession w2
                WHERE w2.status = 'COMPLETED'
                AND w2.startedAt >= :since
            )
            """)
    List<Long> findUserIdsNotWalkedSince(@Param("since") LocalDateTime since);

    // 특정 월의 완료된 산책 거리 합계 (미터) - PostgreSQL EXTRACT 사용
    @Query(value = """
            SELECT COALESCE(SUM(ws.distance_meters), 0)
            FROM walk_sessions ws
            WHERE ws.user_id = :userId
            AND ws.status = 'COMPLETED'
            AND EXTRACT(YEAR FROM ws.started_at) = :year
            AND EXTRACT(MONTH FROM ws.started_at) = :month
            """, nativeQuery = true)
    int sumDistanceByUserAndMonth(@Param("userId") Long userId,
                                   @Param("year") int year,
                                   @Param("month") int month);
}
