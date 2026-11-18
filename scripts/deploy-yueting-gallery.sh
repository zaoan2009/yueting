#!/usr/bin/env bash
# 将 docs/app-gallery 同步到服务器 /srv/yueting，供 Caddy /yueting/* 托管。
# 用法：HOST=root@121.196.223.85 ./scripts/deploy-yueting-gallery.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${HOST:?请设置 HOST，例如 root@121.196.223.85}"
SRC="$ROOT/docs/app-gallery"
python3 "$ROOT/scripts/export-app-gallery.py"
ssh "$HOST" 'mkdir -p /srv/yueting'
rsync -az --delete \
  --exclude 'posters/' \
  --exclude 'CHECKLIST.md' \
  --exclude 'README.md' \
  "$SRC/" "$HOST:/srv/yueting/"
# 若远端 Caddyfile 尚未包含 /yueting，请同步 server/deploy/Caddyfile 后重载 caddy。
echo "已同步至 $HOST:/srv/yueting/"
echo "隐私政策示例：https://121.196.223.85/yueting/privacy.html"
