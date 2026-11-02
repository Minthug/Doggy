-- Runtime scoring does not read raw OSM tags or the plain geometry index.
-- Keep only the compact fields and the meter-based geography index.
ALTER TABLE traffic_map_features
    DROP COLUMN IF EXISTS tags;

DROP INDEX IF EXISTS idx_traffic_map_features_geom;

-- The staging table is only needed during an import. Keeping it would duplicate
-- nearly all nationwide geometries until the next refresh.
DROP TABLE IF EXISTS osm_context_features_stage;
DROP TABLE IF EXISTS osm2pgsql_properties;
