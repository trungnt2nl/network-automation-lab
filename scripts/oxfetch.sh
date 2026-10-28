#!/bin/bash
# Usage: scripts/oxfetch.sh NODE      (vi du: scripts/oxfetch.sh R1)
# Ep Oxidized sao luu NODE ngay, cho toi da 2 phut cho den khi co commit moi trong Git.
# Oxidized mac dinh chi sao luu moi gio (interval) nen can ep khi thu nghiem.
# Kho Git do container tao (UID 30000) nen doc bang sudo + safe.directory.
cd "$(dirname "$0")/../docker" || exit 1
G=(sudo git -c 'safe.directory=*' --git-dir=oxidized/oxidized.git)
before=$("${G[@]}" rev-list --count HEAD)
curl -s "http://localhost:8888/node/next/$1" >/dev/null
for i in $(seq 1 24); do
  sleep 5
  now=$("${G[@]}" rev-list --count HEAD)
  if [ "$now" -gt "$before" ]; then
    echo "Co commit moi sau $((i*5)) giay"
    exit 0
  fi
done
echo "Het thoi gian cho: khong co thay doi moi hoac Oxidized chua chay"
