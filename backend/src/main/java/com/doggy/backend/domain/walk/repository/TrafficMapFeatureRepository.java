package com.doggy.backend.domain.walk.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.IntStream;

@Repository
@RequiredArgsConstructor
public class TrafficMapFeatureRepository {

    private static final String CONTEXT_QUERY_TEMPLATE = """
            WITH candidates(candidate_index, lng, lat) AS (
                VALUES %s
            ), candidate_locations AS (
                SELECT candidate_index,
                       ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography AS location
                FROM candidates
            )
            SELECT
                c.candidate_index,
                COALESCE(context.near_signal, false) AS near_signal,
                COALESCE(context.near_crosswalk, false) AS near_crosswalk,
                COALESCE(context.near_intersection, false) AS near_intersection,
                COALESCE(context.near_road, false) AS near_road,
                COALESCE(context.near_walking_area, false) AS near_walking_area
            FROM candidate_locations c
            CROSS JOIN LATERAL (
                SELECT
                    bool_or(f.feature_type = 'TRAFFIC_SIGNAL') AS near_signal,
                    bool_or(f.feature_type = 'CROSSWALK'
                        AND ST_DWithin(f.geom::geography, c.location, 15, false)) AS near_crosswalk,
                    bool_or(f.feature_type = 'INTERSECTION') AS near_intersection,
                    bool_or(f.feature_type = 'ROAD'
                        AND ST_DWithin(f.geom::geography, c.location, 12, false)) AS near_road,
                    bool_or(f.feature_type IN ('FOOTWAY', 'PARK')
                        AND ST_DWithin(f.geom::geography, c.location, 15, false)) AS near_walking_area
                FROM traffic_map_features f
                WHERE ST_DWithin(f.geom::geography, c.location, 20, false)
            ) context
            ORDER BY c.candidate_index
            """;

    private final JdbcTemplate jdbcTemplate;

    public List<TrafficContext> findContexts(List<TrafficCoordinate> coordinates) {
        if (coordinates == null || coordinates.isEmpty()) {
            return List.of();
        }

        String values = IntStream.range(0, coordinates.size())
                .mapToObj(index -> "(?, ?, ?)")
                .collect(java.util.stream.Collectors.joining(", "));
        List<Object> params = new ArrayList<>(coordinates.size() * 3);
        for (int index = 0; index < coordinates.size(); index++) {
            TrafficCoordinate coordinate = coordinates.get(index);
            params.add(index);
            params.add(coordinate.lng());
            params.add(coordinate.lat());
        }

        // The nationwide index scan's high estimated cost triggers slower JIT compilation.
        // This call runs inside walk completion's transaction; SET LOCAL resets at commit.
        jdbcTemplate.execute("SET LOCAL jit = off");
        return jdbcTemplate.query(
                CONTEXT_QUERY_TEMPLATE.formatted(values),
                (rs, rowNum) -> new TrafficContext(
                        rs.getBoolean("near_signal"),
                        rs.getBoolean("near_crosswalk"),
                        rs.getBoolean("near_intersection"),
                        rs.getBoolean("near_road"),
                        rs.getBoolean("near_walking_area")
                ),
                params.toArray()
        );
    }

    public record TrafficCoordinate(double lat, double lng) {}

    public record TrafficContext(
            boolean nearSignal,
            boolean nearCrosswalk,
            boolean nearIntersection,
            boolean nearRoad,
            boolean nearWalkingArea
    ) {
        public static TrafficContext neutral() {
            return new TrafficContext(false, false, false, false, false);
        }
    }
}
