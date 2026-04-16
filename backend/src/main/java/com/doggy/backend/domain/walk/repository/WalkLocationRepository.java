package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.WalkLocation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface WalkLocationRepository extends JpaRepository<WalkLocation, Long> {

    Optional<WalkLocation> findByWalkSession_Id(Long sessionId);

    void deleteByWalkSession_Id(Long sessionId);

    /**
     * Haversine 공식으로 반경 내 활성 산책 세션 위치 조회
     * staleThreshold 이후에 갱신된 위치만 포함 (오래된 데이터 제외)
     */
    @Query(value = """
            SELECT wl.* FROM walk_locations wl
            JOIN walk_sessions ws ON ws.id = wl.walk_session_id
            WHERE ws.status IN ('IN_PROGRESS', 'PAUSED')
              AND wl.walk_session_id != :sessionId
              AND (6371000 * acos(
                    LEAST(1.0,
                      cos(radians(:lat)) * cos(radians(wl.lat)) * cos(radians(wl.lng) - radians(:lng))
                      + sin(radians(:lat)) * sin(radians(wl.lat))
                    )
                  )) <= :radiusMeters
              AND wl.updated_at > :staleThreshold
            """, nativeQuery = true)
    List<WalkLocation> findNearby(
            @Param("sessionId") Long sessionId,
            @Param("lat") double lat,
            @Param("lng") double lng,
            @Param("radiusMeters") double radiusMeters,
            @Param("staleThreshold") LocalDateTime staleThreshold
    );
}
