#!/usr/bin/env bash
set +x
set -euo pipefail

if [[ ! -t 0 ]]; then
  echo '터미널에서 직접 실행하세요.' >&2
  exit 1
fi

read -r -s -p 'NCP Access Key ID: ' access_key
printf '\n'
read -r -s -p 'NCP Secret Key: ' secret_key
printf '\n'
trap 'unset access_key secret_key' EXIT

if [[ -z "$access_key" || -z "$secret_key" ]]; then
  echo '두 키를 모두 입력해야 합니다.' >&2
  exit 1
fi

{
  printf 'DOGGY_OBJECT_BUCKET=doggy\n'
  printf 'DOGGY_OBJECT_ACCESS_KEY=%q\n' "$access_key"
  printf 'DOGGY_OBJECT_SECRET_KEY=%q\n' "$secret_key"
} | ssh -o BatchMode=yes -T doggy \
  'set -eu; backup_key_tmp=$(mktemp /etc/doggy-backup-object-storage.env.XXXXXX); cat > "$backup_key_tmp"; chmod 600 "$backup_key_tmp"; chown root:root "$backup_key_tmp"; mv "$backup_key_tmp" /etc/doggy-backup-object-storage.env'

unset access_key secret_key

ssh -o BatchMode=yes doggy 'systemctl start doggy-backup.service && systemctl show doggy-backup.service -p Result -p ExecMainStatus --no-pager && journalctl -u doggy-backup.service -n 12 --no-pager -o cat | grep -E "uploaded=|backup_dir=|offsite_upload=" | tail -n 5'
