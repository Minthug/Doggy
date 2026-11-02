-- Runtime scoring only needs a feature category and its geometry. Rebuild the
-- table so columns dropped by earlier migrations no longer occupy heap space,
-- and remove the primary/unique indexes used only by the one-time OSM import.
CREATE TABLE traffic_map_features_compact (
    feature_type VARCHAR(32) NOT NULL,
    geom         geometry(Geometry, 4326) NOT NULL,
    CONSTRAINT ck_traffic_map_features_compact_type CHECK (
        feature_type IN ('ROAD', 'CROSSWALK', 'TRAFFIC_SIGNAL', 'INTERSECTION', 'FOOTWAY', 'PARK')
    )
);

INSERT INTO traffic_map_features_compact (feature_type, geom)
SELECT feature_type, geom
FROM traffic_map_features;

DROP TABLE traffic_map_features;
ALTER TABLE traffic_map_features_compact RENAME TO traffic_map_features;
ALTER TABLE traffic_map_features
    RENAME CONSTRAINT ck_traffic_map_features_compact_type TO ck_traffic_map_features_type;

CREATE INDEX idx_traffic_map_features_geography
    ON traffic_map_features USING GIST ((geom::geography));

CREATE INDEX idx_traffic_map_features_type
    ON traffic_map_features (feature_type);

ANALYZE traffic_map_features;
