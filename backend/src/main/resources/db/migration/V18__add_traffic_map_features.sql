CREATE TABLE IF NOT EXISTS traffic_map_features (
    id           BIGSERIAL PRIMARY KEY,
    feature_type VARCHAR(32) NOT NULL,
    subtype      TEXT,
    source       VARCHAR(32) NOT NULL,
    source_type  VARCHAR(16) NOT NULL DEFAULT 'UNKNOWN',
    source_id    VARCHAR(64) NOT NULL,
    tags         JSONB NOT NULL DEFAULT '{}'::jsonb,
    geom         geometry(Geometry, 4326) NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_traffic_map_features_type CHECK (
        feature_type IN ('ROAD', 'CROSSWALK', 'TRAFFIC_SIGNAL', 'INTERSECTION', 'FOOTWAY', 'PARK')
    ),
    CONSTRAINT uq_traffic_map_features_source UNIQUE (source, source_type, source_id, feature_type)
);

ALTER TABLE traffic_map_features
    ALTER COLUMN subtype TYPE TEXT;

CREATE INDEX IF NOT EXISTS idx_traffic_map_features_geom
    ON traffic_map_features USING GIST (geom);

-- Meter-based ST_DWithin queries use geography, so keep a matching expression index.
CREATE INDEX IF NOT EXISTS idx_traffic_map_features_geography
    ON traffic_map_features USING GIST ((geom::geography));

CREATE INDEX IF NOT EXISTS idx_traffic_map_features_type
    ON traffic_map_features (feature_type);
