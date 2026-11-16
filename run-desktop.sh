#!/bin/sh
set -eu
cd "$(dirname "$0")"
PORT=8765
python3 -m http.server "$PORT" --directory www >/tmp/parcel-selection-server.log 2>&1 &
PID=$!
trap 'kill "$PID" 2>/dev/null || true' EXIT INT TERM
URL="http://127.0.0.1:$PORT/"
if command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL" >/dev/null 2>&1 || true
elif command -v open >/dev/null 2>&1; then open "$URL" >/dev/null 2>&1 || true
else printf 'افتح هذا العنوان في المتصفح: %s\n' "$URL"; fi
printf 'السيرفر المحلي يعمل ما دامت هذه النافذة مفتوحة: %s\n' "$URL"
wait "$PID"
