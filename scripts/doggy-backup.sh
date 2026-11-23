#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT=/var/backups/doggy
IMAGE_DIR=/var/doggy/images
RETENTION_DAYS=${DOGGY_BACKUP_RETENTION_DAYS:-3}
STAMP=$(date +%Y%m%d-%H%M%S)
DEST="$BACKUP_ROOT/$STAMP"

mkdir -p "$DEST"
chmod 700 "$BACKUP_ROOT" "$DEST"

DB_NAME=$(python3 - <<'PY'
from pathlib import Path
from urllib.parse import urlparse
values = {}
for line in Path("/app/.env").read_text().splitlines():
    if "=" in line and not line.strip().startswith("#"):
        k, v = line.split("=", 1)
        values[k] = v
url = values.get("DB_URL") or values.get("SPRING_DATASOURCE_URL", "")
if url.startswith("jdbc:"):
    url = url[5:]
print(urlparse(url).path.lstrip("/"))
PY
)

if [[ -z "$DB_NAME" ]]; then
  echo "DB name could not be resolved" >&2
  exit 1
fi

sudo -u postgres pg_dump -Fc -Z 9 -d "$DB_NAME" > "$DEST/postgres.dump"
test -s "$DEST/postgres.dump"
pg_restore --list "$DEST/postgres.dump" > /dev/null

if [[ -d "$IMAGE_DIR" ]]; then
  tar -C "$IMAGE_DIR" -czf "$DEST/images.tar.gz" .
else
  tar -czf "$DEST/images.tar.gz" --files-from /dev/null
fi
test -s "$DEST/images.tar.gz"
tar -tzf "$DEST/images.tar.gz" > /dev/null

sha256sum "$DEST/postgres.dump" "$DEST/images.tar.gz" > "$DEST/SHA256SUMS"
sha256sum -c "$DEST/SHA256SUMS" > /dev/null
if [[ -f /etc/doggy-backup-object-storage.env ]]; then
  set -a
  source /etc/doggy-backup-object-storage.env
  set +a
  python3 /usr/local/sbin/doggy-upload-backup "$DEST"
else
  echo "offsite_upload=not_configured"
fi
find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -regextype posix-extended -type d \
  -regex "$BACKUP_ROOT/[0-9]{8}-[0-9]{6}" -mtime +"$RETENTION_DAYS" -exec rm -rf -- {} +
ln -sfn "$DEST" "$BACKUP_ROOT/latest"

echo "backup_dir=$DEST"
echo "db_dump=$(du -h "$DEST/postgres.dump" | awk '{print $1}')"
echo "images_archive=$(du -h "$DEST/images.tar.gz" | awk '{print $1}')"
