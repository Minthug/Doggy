#!/usr/bin/env bash
set -euo pipefail

WEBHOOK=$(python3 - <<'PY'
from pathlib import Path
for line in Path('/app/.env').read_text().splitlines():
    if line.startswith('ALERT_DISCORD_WEBHOOK_URL='):
        print(line.split('=', 1)[1])
        break
PY
)

if [[ -z "$WEBHOOK" ]]; then
  echo 'backup failed, but Discord webhook is not configured' >&2
  exit 0
fi

BODY=$(python3 - <<'PY'
import json
import socket
print(json.dumps({'content': f'Doggy 백업 실패: {socket.gethostname()} 서버의 doggy-backup.service를 확인하세요.'}))
PY
)
curl -fsS --max-time 10 -H 'Content-Type: application/json' --data "$BODY" "$WEBHOOK" > /dev/null
