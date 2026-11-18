ALTER TABLE walk_sessions
    ADD COLUMN public_search_lat DOUBLE PRECISION,
    ADD COLUMN public_search_lng DOUBLE PRECISION;

WITH public_routes AS (
    SELECT ws.id AS session_id,
           COALESCE(ws.route_geo_json, (
               SELECT CASE WHEN COUNT(*) >= 2 THEN
                   ST_AsGeoJSON(ST_SimplifyPreserveTopology(
                       ST_MakeLine(ST_MakePoint(wp.lng, wp.lat) ORDER BY wp.recorded_at),
                       0.00013))
               END
               FROM walk_points wp WHERE wp.session_id = ws.id
           )) AS geojson
    FROM walk_sessions ws
    WHERE ws.is_public = true AND ws.status = 'COMPLETED'
), route_points AS (
    SELECT route.session_id, point.ordinality AS id,
           (point.value->>1)::double precision AS lat,
           (point.value->>0)::double precision AS lng
    FROM public_routes route
    CROSS JOIN LATERAL jsonb_array_elements(route.geojson::jsonb->'coordinates')
        WITH ORDINALITY AS point(value, ordinality)
), legs AS (
    SELECT point.session_id, point.id, point.lat, point.lng,
           COALESCE(ST_DistanceSphere(
               ST_MakePoint(point.lng, point.lat),
               ST_MakePoint(
                   LAG(point.lng) OVER (PARTITION BY point.session_id ORDER BY point.id),
                   LAG(point.lat) OVER (PARTITION BY point.session_id ORDER BY point.id)
               )), 0) AS meters
    FROM route_points point
), traveled AS (
    SELECT legs.*,
           SUM(meters) OVER (PARTITION BY session_id ORDER BY id) AS distance_from_start,
           SUM(meters) OVER (PARTITION BY session_id) AS total_distance
    FROM legs
), visible AS (
    SELECT traveled.*,
           ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY distance_from_start, id) AS point_index,
           COUNT(*) OVER (PARTITION BY session_id) AS visible_count
    FROM traveled
    WHERE distance_from_start >= 200 AND total_distance - distance_from_start >= 200
)
UPDATE walk_sessions ws
SET public_search_lat = FLOOR(visible.lat * 1000 + 0.5) / 1000.0,
    public_search_lng = FLOOR(visible.lng * 1000 + 0.5) / 1000.0
FROM visible
WHERE ws.id = visible.session_id
  AND visible.point_index = 1
  AND visible.visible_count >= 2;

CREATE INDEX idx_walk_sessions_public_search_lat
    ON walk_sessions (public_search_lat)
    WHERE is_public = true AND status = 'COMPLETED' AND public_search_lat IS NOT NULL;
