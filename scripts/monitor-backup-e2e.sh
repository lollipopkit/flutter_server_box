#!/bin/sh
# The monitor's settings backup end to end, on this machine (issue #1771):
#
# 1. rclone's WebDAV and nginx's (Docker, alpine, with dav-ext) started on
#    loopback, each with a random account;
# 2. `tests/monitor_backup_e2e.rs` against each;
# 3. a monitor serving the panel, and `frontend/e2e/monitor_backup.e2e.ts`
#    (Playwright) backing it up to rclone's and restoring it;
# 4. the CLI on a second, empty monitor: `backup restore` from that folder,
#    `backup list`, `backup run` with what the restore left;
# 5. the newest backup opened with Go's age (`monitor-backup-e2e/`), nothing
#    of ServerBox's, and what is in it read.
#
#     scripts/monitor-backup-e2e.sh
#
# Needs rclone, docker, go, sqlite3, htpasswd, node. Secrets are generated
# here and passed through the environment, never on a command line.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sbm-backup-e2e.XXXXXX")
RCLONE_PORT=18080
NGINX_PORT=18081
PANEL_PORT=3790
NGINX=sbm-backup-e2e-nginx

PIDS=""
cleanup() {
    for p in $PIDS; do kill "$p" 2>/dev/null || true; done
    docker rm -f "$NGINX" >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

random() { openssl rand -hex "$1"; }
export SBM_E2E_WEBDAV_USER=sbm-e2e
SBM_E2E_WEBDAV_PASSWORD=$(random 16)
SBM_E2E_PANEL_PASSWORD=$(random 12)
SBM_E2E_BACKUP_PASSPHRASE="e2e passphrase $(random 8)"
export SBM_E2E_WEBDAV_PASSWORD SBM_E2E_PANEL_PASSWORD SBM_E2E_BACKUP_PASSPHRASE

wait_for() { # url
    i=0
    until curl -s --noproxy '*' -o /dev/null "$1"; do
        i=$((i + 1)); [ "$i" -lt 100 ] || { echo "no answer from $1" >&2; exit 1; }
        sleep 0.2
    done
}

echo "== WebDAV servers"
mkdir -p "$WORK/rclone"
printf '%s' "$SBM_E2E_WEBDAV_PASSWORD" | htpasswd -iBc "$WORK/htpasswd" "$SBM_E2E_WEBDAV_USER" 2>/dev/null
rclone serve webdav --addr "127.0.0.1:$RCLONE_PORT" --htpasswd "$WORK/htpasswd" "$WORK/rclone" >"$WORK/rclone.log" 2>&1 &
PIDS="$PIDS $!"
wait_for "http://127.0.0.1:$RCLONE_PORT/"

docker rm -f "$NGINX" >/dev/null 2>&1 || true
# nginx's WebDAV (PUT, MKCOL, MOVE, DELETE) with the dav-ext module's PROPFIND,
# on Alpine. Apache's mod_dav would need a DBM driver Alpine's apr-util lacks.
docker run -d --name "$NGINX" -p "127.0.0.1:$NGINX_PORT:80" alpine:3.22 sleep infinity >/dev/null
docker exec -i "$NGINX" sh -s <<'EOF'
set -e
apk add --no-cache nginx nginx-mod-http-dav-ext apache2-utils >/dev/null
mkdir -p /var/www/dav
chown nginx:nginx /var/www/dav
cat >/etc/nginx/http.d/default.conf <<'CONF'
server {
    listen 80;
    client_max_body_size 200m;
    location /dav/ {
        root /var/www;
        dav_methods PUT DELETE MKCOL COPY MOVE;
        dav_ext_methods PROPFIND OPTIONS;
        auth_basic "dav";
        auth_basic_user_file /etc/nginx/dav.htpasswd;
    }
}
CONF
EOF
printf '%s' "$SBM_E2E_WEBDAV_PASSWORD" | docker exec -i "$NGINX" htpasswd -ic /etc/nginx/dav.htpasswd "$SBM_E2E_WEBDAV_USER" 2>/dev/null
docker exec "$NGINX" nginx
wait_for "http://127.0.0.1:$NGINX_PORT/"

cd "$ROOT"
for url in "http://127.0.0.1:$RCLONE_PORT/" "http://127.0.0.1:$NGINX_PORT/dav/"; do
    echo "== API against $url"
    SBM_E2E_WEBDAV_URL=$url cargo test -q -p server_box_monitor --test monitor_backup_e2e -- --ignored --nocapture
done

echo "== The panel"
cargo build -q -p server_box_monitor
BIN=$(cargo metadata --format-version 1 --no-deps | python3 -c 'import json,sys; print(json.load(sys.stdin)["target_directory"])')/debug/server_box_monitor
(cd monitor/frontend && npm run -s build >/dev/null)

# A monitor in a folder of its own, the panel's files reached as it reaches them.
start_monitor() { # dir port
    mkdir -p "$1"
    ln -sfn "$ROOT/monitor/frontend" "$1/frontend"
    (cd "$1" && DATABASE_URL="sqlite://$1/monitor.db" "$BIN" password --password-env SBM_E2E_PANEL_PASSWORD >/dev/null)
    (cd "$1" && DATABASE_URL="sqlite://$1/monitor.db" RUST_LOG=info exec "$BIN" serve --addr "127.0.0.1:$2" >"$1/monitor.log" 2>&1) &
    PIDS="$PIDS $!"
    wait_for "http://127.0.0.1:$2/api/v1/health"
}
A="$WORK/a"
start_monitor "$A" "$PANEL_PORT"
sqlite3 "$A/monitor.db" "INSERT INTO snippet (id, name, script, position, updated_at) VALUES ('e2e-backup', 'Backed up', 'uptime', 0, 'x')"
FOLDER="http://127.0.0.1:$RCLONE_PORT/panel-box/"
(cd monitor/frontend && SBM_E2E_PANEL_URL="http://127.0.0.1:$PANEL_PORT" SBM_E2E_WEBDAV_URL=$FOLDER SBM_E2E_BACKUP_DB="$A/monitor.db" \
    npx playwright test monitor_backup)

echo "== The CLI on an empty monitor"
B="$WORK/b"
mkdir -p "$B"
(cd "$B" && DATABASE_URL="sqlite://$B/monitor.db" "$BIN" backup restore --url "$FOLDER" --user "$SBM_E2E_WEBDAV_USER" \
    --password-env SBM_E2E_WEBDAV_PASSWORD --passphrase-env SBM_E2E_BACKUP_PASSPHRASE)
[ "$(sqlite3 "$B/monitor.db" "SELECT name FROM snippet WHERE id = 'e2e-backup'")" = "Backed up" ]
[ "$(sqlite3 "$B/monitor.db" "SELECT url FROM monitor_backup")" = "$FOLDER" ]
(cd "$B" && DATABASE_URL="sqlite://$B/monitor.db" "$BIN" backup list) | tee "$WORK/list"
(cd "$B" && DATABASE_URL="sqlite://$B/monitor.db" "$BIN" backup run)
(cd "$B" && DATABASE_URL="sqlite://$B/monitor.db" "$BIN" backup list) >"$WORK/list2"
[ "$(wc -l <"$WORK/list2")" -eq $(($(wc -l <"$WORK/list") + 1)) ]

echo "== Opened with Go's age"
NEWEST=$(head -n1 "$WORK/list2" | cut -f1)
KEY=$(ls "$WORK/rclone/panel-box" | grep '^serverbox-monitor-key-')
(cd scripts/monitor-backup-e2e && SBM_BACKUP_PASSPHRASE=$SBM_E2E_BACKUP_PASSPHRASE go run . "$WORK/rclone/panel-box/$KEY" "$WORK/rclone/panel-box/$NEWEST" "$WORK/opened.tar.gz")
mkdir "$WORK/opened"
tar -xzf "$WORK/opened.tar.gz" -C "$WORK/opened"
ls "$WORK/opened"
[ -f "$WORK/opened/manifest.json" ] && [ -f "$WORK/opened/settings.db" ]
[ "$(sqlite3 "$WORK/opened/settings.db" "SELECT name FROM snippet WHERE id = 'e2e-backup'")" = "Backed up" ]
[ "$(sqlite3 "$WORK/opened/settings.db" "SELECT COUNT(*) FROM access_log")" = "0" ]

echo "== All passed"
