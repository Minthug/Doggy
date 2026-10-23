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

    @Query(value = """
            WITH target_context AS (
                SELECT user_id, household_id,
                       COALESCE(ended_at, started_at) AS walked_until
                FROM walk_sessions
                WHERE id = :sessionId
            ),
            target_route AS (
                SELECT ST_MakeLine(
                           ST_SetSRID(ST_MakePoint(wp.lng, wp.lat), 4326)
                           ORDER BY wp.recorded_at
                       ) AS geom
                FROM walk_points wp
                WHERE wp.session_id = :sessionId
                HAVING COUNT(*) >= 2
            ),
            candidate_routes AS (
                SELECT wp.session_id,
                       ST_MakeLine(
                           ST_SetSRID(ST_MakePoint(wp.lng, wp.lat), 4326)
                           ORDER BY wp.recorded_at
                       ) AS geom
                FROM walk_points wp
                JOIN walk_sessions ws ON ws.id = wp.session_id
                CROSS JOIN target_context tc
                WHERE ws.id <> :sessionId
                  AND ws.status = 'COMPLETED'
                  AND ws.is_public = true
                  AND ws.started_at <= tc.walked_until
                  AND ws.started_at >= tc.walked_until - INTERVAL '3 days'
                  AND ws.user_id <> tc.user_id
                  AND (tc.household_id IS NULL OR ws.household_id IS NULL
                       OR ws.household_id <> tc.household_id)
                GROUP BY wp.session_id
                HAVING COUNT(*) >= 2
            )
            SELECT cr.session_id
            FROM candidate_routes cr
            JOIN walk_sessions ws ON ws.id = cr.session_id
            CROSS JOIN target_route tr
            WHERE ST_DWithin(tr.geom::geography, cr.geom::geography, :radiusMeters)
            ORDER BY ws.started_at DESC
            LIMIT :maxResults
            """, nativeQuery = true)
    List<Long> findNearbyPublicTraceSessionIds(
            @Param("sessionId") Long sessionId,
            @Param("radiusMeters") double radiusMeters,
            @Param("maxResults") int maxResults);

    void deleteAllBySessionId(Long sessionId);

    @Modifying
    @Query("DELETE FROM WalkPoint wp WHERE wp.session.id IN :sessionIds")
    void deleteAllBySessionIdIn(@Param("sessionIds") List<Long> sessionIds);

    boolean existsBySessionId(Long sessionId);
}
