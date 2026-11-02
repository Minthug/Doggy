#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OSM_DIR="${OSM_DIR:-/private/tmp/doggy-osm}"
OSM_PBF="${OSM_PBF:-${OSM_DIR}/south-korea-latest.osm.pbf}"
OSM_URL="${OSM_URL:-https://download.geofabrik.de/asia/south-korea-latest.osm.pbf}"
DB_CONTAINER="${DB_CONTAINER:-doggy-db}"
DB_NAME="${DB_NAME:-doggy}"
DB_USER="${DB_USER:-doggy}"
DB_PASSWORD="${DB_PASSWORD:-doggy}"
DB_NETWORK="${DB_NETWORK:-doggy_default}"
DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-5432}"

mkdir -p "${OSM_DIR}"

if [[ ! -s "${OSM_PBF}" ]]; then
    echo "Downloading South Korea OSM extract..."
    curl -L --fail --retry 3 -o "${OSM_PBF}" "${OSM_URL}"
fi

echo "Checking compact traffic feature schema..."
SCHEMA_COLUMNS="$({ docker exec "${DB_CONTAINER}" psql -At -U "${DB_USER}" -d "${DB_NAME}" -c \
    "SELECT string_agg(column_name, ',' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'traffic_map_features';"; } | tr -d '\r')"
if [[ "${SCHEMA_COLUMNS}" != "feature_type,geom" ]]; then
    echo "traffic_map_features is not on the compact schema. Start the backend to apply Flyway migrations first." >&2
    exit 1
fi

echo "Importing selected OSM features..."
docker run --rm \
    --network "${DB_NETWORK}" \
    -e "PGPASSWORD=${DB_PASSWORD}" \
    -v "${OSM_PBF}:/data/south-korea.osm.pbf:ro" \
    -v "${PROJECT_DIR}/scripts/osm/traffic-context.lua:/data/traffic-context.lua:ro" \
    iboates/osm2pgsql:latest \
    -O flex -S /data/traffic-context.lua --create --slim --drop \
    -H "${DB_HOST}" -P "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    /data/south-korea.osm.pbf

echo "Replacing application traffic context data and deriving intersections..."
docker exec -i "${DB_CONTAINER}" psql -v ON_ERROR_STOP=1 -U "${DB_USER}" -d "${DB_NAME}" \
    < "${PROJECT_DIR}/scripts/osm/merge-traffic-context.sql"

docker exec "${DB_CONTAINER}" psql -U "${DB_USER}" -d "${DB_NAME}" -c \
    "SELECT feature_type, count(*) FROM traffic_map_features GROUP BY feature_type ORDER BY feature_type;"
