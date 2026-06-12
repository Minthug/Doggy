package com.doggy.backend.domain.walk.repository;

import com.doggy.backend.domain.walk.entity.WalkPoint;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface WalkPointRepository extends JpaRepository<WalkPoint, Long> {

    List<WalkPoint> findAllBySessionIdOrderByRecordedAt(Long sessionId);

    @Query(value = """
            SELECT CASE
                WHEN COUNT(*) < 2 THEN NULL
                ELSE ST_AsGeoJSON(
                    ST_SimplifyPreserveTopology(
                        ST_MakeLine(ST_MakePoint(wp.lng, wp.lat) ORDER BY wp.recorded_at),
                        0.00013
                    )
                )
            END
            FROM walk_points wp
            WHERE wp.session_id = :sessionId
            """, nativeQuery = true)
    String findRouteGeoJsonBySessionId(@Param("sessionId") Long sessionId);

    @Query(value = """
            SELECT wp.session_id,
                   CASE WHEN COUNT(*) < 2 THEN NULL
                   ELSE ST_AsGeoJSON(
                       ST_SimplifyPreserveTopology(
                           ST_MakeLine(ST_MakePoint(wp.lng, wp.lat) ORDER BY wp.recorded_at),
                           0.00013
                       )
                   ) END AS geojson
            FROM walk_points wp
            WHERE wp.session_id IN :sessionIds
            GROUP BY wp.session_id
            """, nativeQuery = true)
    List<Object[]> findRouteGeoJsonBySessionIds(@Param("sessionIds") Collection<Long> sessionIds);

    void deleteAllBySessionId(Long sessionId);

    @Modifying
    @Query("DELETE FROM WalkPoint wp WHERE wp.session.id IN :sessionIds")
    void deleteAllBySessionIdIn(@Param("sessionIds") List<Long> sessionIds);

    boolean existsBySessionId(Long sessionId);
}
