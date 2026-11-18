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
            WITH numbered AS (
                SELECT wp.*, SUM(CASE WHEN wp.segment_start THEN 1 ELSE 0 END)
                    OVER (ORDER BY wp.recorded_at, wp.id) AS segment_no
                FROM walk_points wp WHERE wp.session_id = :sessionId
            ), segments AS (
                SELECT segment_no,
                       ST_SimplifyPreserveTopology(
                           ST_MakeLine(ST_MakePoint(lng, lat) ORDER BY recorded_at, id), 0.00013) AS geom
                FROM numbered GROUP BY segment_no HAVING COUNT(*) >= 2
            )
            SELECT CASE WHEN COUNT(*) = 0 THEN NULL
                        WHEN COUNT(*) = 1 THEN ST_AsGeoJSON((ARRAY_AGG(geom ORDER BY segment_no))[1])
                        ELSE ST_AsGeoJSON(ST_Collect(geom ORDER BY segment_no)) END
            FROM segments
            """, nativeQuery = true)
    String findRouteGeoJsonBySessionId(@Param("sessionId") Long sessionId);

    @Query(value = """
            WITH numbered AS (
                SELECT wp.*, SUM(CASE WHEN wp.segment_start THEN 1 ELSE 0 END)
                    OVER (PARTITION BY wp.session_id ORDER BY wp.recorded_at, wp.id) AS segment_no
                FROM walk_points wp WHERE wp.session_id IN :sessionIds
            ), segments AS (
                SELECT session_id, segment_no,
                       ST_SimplifyPreserveTopology(
                           ST_MakeLine(ST_MakePoint(lng, lat) ORDER BY recorded_at, id), 0.00013) AS geom
                FROM numbered GROUP BY session_id, segment_no HAVING COUNT(*) >= 2
            )
            SELECT session_id,
                   CASE WHEN COUNT(*) = 1 THEN ST_AsGeoJSON((ARRAY_AGG(geom ORDER BY segment_no))[1])
                        ELSE ST_AsGeoJSON(ST_Collect(geom ORDER BY segment_no)) END AS geojson
            FROM segments GROUP BY session_id
            """, nativeQuery = true)
    List<Object[]> findRouteGeoJsonBySessionIds(@Param("sessionIds") Collection<Long> sessionIds);

    @Query(value = """
            WITH target_context AS (
                SELECT user_id, household_id,
                       COALESCE(ended_at, started_at) AS walked_until
                FROM walk_sessions
                WHERE id = :sessionId
            ),
            eligible_sessions AS (
                SELECT ws.id FROM walk_sessions ws CROSS JOIN target_context tc
                WHERE ws.id <> :sessionId
                  AND ws.status = 'COMPLETED' AND ws.is_public = true
                  AND ws.started_at <= tc.walked_until
                  AND ws.started_at >= tc.walked_until - INTERVAL '3 days'
                  AND ws.user_id <> tc.user_id
                  AND (tc.household_id IS NULL OR ws.household_id IS NULL
                       OR ws.household_id <> tc.household_id)
            ),
            numbered AS (
                SELECT wp.*, SUM(CASE WHEN wp.segment_start THEN 1 ELSE 0 END)
                    OVER (PARTITION BY wp.session_id ORDER BY wp.recorded_at, wp.id) AS segment_no
                FROM walk_points wp
                WHERE wp.session_id = :sessionId
                   OR wp.session_id IN (SELECT id FROM eligible_sessions)
            ), segment_lines AS (
                SELECT session_id, segment_no,
                       ST_MakeLine(ST_SetSRID(ST_MakePoint(lng, lat), 4326)
                                   ORDER BY recorded_at, id) AS geom
                FROM numbered GROUP BY session_id, segment_no HAVING COUNT(*) >= 2
            ), target_route AS (
                SELECT ST_Collect(geom) AS geom FROM segment_lines WHERE session_id = :sessionId
            ), candidate_routes AS (
                SELECT session_id, ST_Collect(geom) AS geom
                FROM segment_lines WHERE session_id IN (SELECT id FROM eligible_sessions)
                GROUP BY session_id
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
