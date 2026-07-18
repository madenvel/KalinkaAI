#!/usr/bin/env bash
# Run the web app locally for development — no deb / root / nginx install
# needed (nginx runs in a rootless podman container).
#
#   scripts/run_web_dev.sh <kalinka-server[:port]>          hot-reload dev
#   scripts/run_web_dev.sh <kalinka-server[:port]> --prod   same-origin check
#
# The first argument is the KALINKA SERVER address (port defaults to 8000),
# e.g. `127.0.0.1` for a local server or `192.168.1.50` for a Pi — NOT the
# :8080 the page is served on.
#
# Dev mode: starts a CORS-enabled proxy on localhost:8080 to the given Kalinka
# server, then `flutter run -d chrome` with hot reload; the app is pointed at
# the proxy via --dart-define=KALINKA_WEB_BACKEND (see main.dart).
#
# Prod mode: `flutter build web` and serve the bundle same-origin at
# http://localhost:8080, approximating production — where kalinka-server
# serves the bundle itself from /usr/share/kalinka-web on its own port.
#
# Uses Chromium via CHROME_EXECUTABLE if Flutter doesn't find Chrome itself.
set -euo pipefail
cd "$(dirname "$0")/.."

PORT=8080
NAME=kalinka-web-dev

usage() { sed -n '2,16p' "$0"; exit 1; }
[ $# -ge 1 ] || usage
BACKEND=$1
[[ "$BACKEND" == *:* ]] || BACKEND="$BACKEND:8000"
MODE=${2:-dev}

# Footgun guard: pointing the proxy at its own port makes a request loop.
if [[ "$BACKEND" == *":$PORT" ]]; then
  echo "error: backend must be the Kalinka server (usually :8000), not the proxy port :$PORT" >&2
  exit 1
fi

# nginx's variable proxy_pass needs an IP — resolve hostnames here.
BHOST=${BACKEND%:*} BPORT=${BACKEND##*:}
if ! [[ "$BHOST" =~ ^[0-9.]+$ ]]; then
  BHOST=$(getent ahostsv4 "$BHOST" | awk '{print $1; exit}')
  [ -n "$BHOST" ] || { echo "error: cannot resolve '$1'" >&2; exit 1; }
  BACKEND="$BHOST:$BPORT"
fi

if command -v podman >/dev/null 2>&1; then RUNNER=podman
elif command -v docker >/dev/null 2>&1; then RUNNER=docker
else echo "podman or docker required" >&2; exit 1; fi

if [ -z "${CHROME_EXECUTABLE:-}" ]; then
  for c in chromium-browser chromium google-chrome google-chrome-stable; do
    if command -v "$c" >/dev/null 2>&1; then
      export CHROME_EXECUTABLE=$(command -v "$c"); break
    fi
  done
fi

CONF=$(mktemp -t kalinka-web-dev-XXXX.conf)
trap '$RUNNER rm -f $NAME >/dev/null 2>&1 || true; rm -f "$CONF"' EXIT
$RUNNER rm -f $NAME >/dev/null 2>&1 || true

VOLUMES=()
if [ "$MODE" = "--prod" ]; then
  flutter build web --release
  # Same-origin static + API proxy — approximates the server-hosted UI
  # (in production kalinka-server serves the bundle itself on its own port).
  cat > "$CONF" <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}
server {
    listen $PORT;
    listen [::]:$PORT;
    root /usr/share/kalinka-web;
    index index.html;
    location / {
        try_files \$uri \$uri/ @backend;
    }
    location @backend {
        proxy_pass http://$BACKEND;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_read_timeout 3600s;
    }
}
EOF
  VOLUMES+=(-v "$PWD/build/web:/usr/share/kalinka-web:ro,Z")
else
  # Bare CORS-enabled proxy: the app itself is served by `flutter run`, which
  # is a different origin, so the proxy must answer preflights and label
  # responses for cross-origin use. WebSockets upgrade through the same route.
  cat > "$CONF" <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}
server {
    listen $PORT;
    listen [::]:$PORT;
    location / {
        if (\$request_method = OPTIONS) {
            add_header Access-Control-Allow-Origin * always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers * always;
            return 204;
        }
        add_header Access-Control-Allow-Origin * always;
        proxy_pass http://$BACKEND;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_read_timeout 3600s;
    }
}
EOF
fi

# --network host reaches both LAN and localhost backends. Our conf replaces
# the image default (which would rootless-fail to bind :80).
$RUNNER run -d --rm --name $NAME --network host \
  -v "$CONF:/etc/nginx/conf.d/default.conf:ro,Z" \
  "${VOLUMES[@]}" \
  docker.io/library/nginx:stable-alpine >/dev/null

# A bind failure (port busy) kills the container silently under -d --rm.
sleep 1
if ! $RUNNER ps --format '{{.Names}}' | grep -qx $NAME; then
  echo "error: proxy failed to start — is port $PORT already in use?" >&2
  exit 1
fi
echo "proxy: localhost:$PORT -> $BACKEND ($RUNNER container '$NAME')"

if [ "$MODE" = "--prod" ]; then
  echo "Serving deb-faithful build at http://localhost:$PORT  (Ctrl-C to stop)"
  command -v xdg-open >/dev/null && xdg-open "http://localhost:$PORT" || true
  $RUNNER logs -f $NAME
else
  flutter run -d chrome --dart-define=KALINKA_WEB_BACKEND=localhost:$PORT
fi
