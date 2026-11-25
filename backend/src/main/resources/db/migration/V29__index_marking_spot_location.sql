CREATE INDEX IF NOT EXISTS idx_marking_spots_location_geography
    ON marking_spots USING GIST ((ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography));
