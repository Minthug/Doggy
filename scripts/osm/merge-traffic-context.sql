BEGIN;

DROP INDEX IF EXISTS idx_traffic_map_features_geom;
DROP INDEX IF EXISTS idx_traffic_map_features_geography;
DROP INDEX IF EXISTS idx_traffic_map_features_type;

TRUNCATE TABLE traffic_map_features;

INSERT INTO traffic_map_features (
    feature_type, geom
)
SELECT
    feature_type,
    geom
FROM osm_context_features_stage;

-- OSM roads are normally split at junction nodes. Endpoints shared by at least
-- three road segments are useful intersection candidates.
WITH road_endpoints AS (
    SELECT osm_id, ST_SnapToGrid(ST_StartPoint(geom), 0.000001) AS geom
    FROM osm_context_features_stage
    WHERE feature_type = 'ROAD' AND GeometryType(geom) = 'LINESTRING'
    UNION ALL
    SELECT osm_id, ST_SnapToGrid(ST_EndPoint(geom), 0.000001) AS geom
    FROM osm_context_features_stage
    WHERE feature_type = 'ROAD' AND GeometryType(geom) = 'LINESTRING'
), intersections AS (
    SELECT geom, count(DISTINCT osm_id) AS road_count
    FROM road_endpoints
    GROUP BY geom
    HAVING count(DISTINCT osm_id) >= 3
)
INSERT INTO traffic_map_features (
    feature_type, geom
)
SELECT
    'INTERSECTION',
    geom
FROM intersections;

CREATE INDEX idx_traffic_map_features_geography
    ON traffic_map_features USING GIST ((geom::geography));
CREATE INDEX idx_traffic_map_features_type
    ON traffic_map_features (feature_type);

ANALYZE traffic_map_features;

DROP TABLE osm_context_features_stage;
DROP TABLE IF EXISTS osm2pgsql_properties;
COMMIT;
