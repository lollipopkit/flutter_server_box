#!/bin/sh
# The app's backup sync end to end, on this machine (issue #1772):
#
# 1. rclone's WebDAV and a monitor agent started on loopback, each with a
#    random account;
# 2. `test/e2e/backup_sync_test.dart` against each: the upload is armored age
#    under the v4 name, another device restores it, a v3-only remote is
#    inherited and moved to v4;
# 3. each uploaded file opened with the `age` CLI and the backup password,
#    nothing of ServerBox's, and what is in it read.
#
#     scripts/app-backup-e2e.sh
#
# Needs rclone, htpasswd, age, expect, cargo and flutter. Secrets are
# generated here and passed through the environment.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sbm-app-backup-e2e.XXXXXX")
WEBDAV_PORT=18090
MONITOR_PORT=3791
# The test's own (`_password` in backup_sync_test.dart).
BACKUP_PASSWORD=e2e-backup-password

PIDS=""
cleanup() {
    for p in $PIDS; do kill "$p" 2>/dev/null || true; done
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

random() { openssl rand -hex "$1"; }
export SBM_E2E_WEBDAV_USER=sbm-e2e
SBM_E2E_WEBDAV_PASSWORD=$(random 16)
SBM_E2E_MONITOR_PASSWORD=$(random 12)
export SBM_E2E_WEBDAV_PASSWORD SBM_E2E_MONITOR_PASSWORD
export SBM_E2E_WEBDAV_URL="http://127.0.0.1:$WEBDAV_PORT/"
export SBM_E2E_MONITOR_ADDR="http://127.0.0.1:$MONITOR_PORT"

wait_for() { # url
    i=0
    until curl -s --noproxy '*' -o /dev/null "$1"; do
        i=$((i + 1)); [ "$i" -lt 150 ] || { echo "no answer from $1" >&2; exit 1; }
        sleep 0.2
    done
}

echo "== WebDAV and a monitor"
mkdir -p "$WORK/rclone" "$WORK/monitor"
printf '%s' "$SBM_E2E_WEBDAV_PASSWORD" | htpasswd -iBc "$WORK/htpasswd" "$SBM_E2E_WEBDAV_USER" 2>/dev/null
rclone serve webdav --addr "127.0.0.1:$WEBDAV_PORT" --htpasswd "$WORK/htpasswd" "$WORK/rclone" >"$WORK/rclone.log" 2>&1 &
PIDS="$PIDS $!"
wait_for "$SBM_E2E_WEBDAV_URL"

cd "$ROOT"
cargo build -q -p server_box_monitor
BIN=$(cargo metadata --format-version 1 --no-deps | python3 -c 'import json,sys; print(json.load(sys.stdin)["target_directory"])')/debug/server_box_monitor
M="$WORK/monitor"
(cd "$M" && DATABASE_URL="sqlite://$M/monitor.db" "$BIN" password --password-env SBM_E2E_MONITOR_PASSWORD >/dev/null)
(cd "$M" && DATABASE_URL="sqlite://$M/monitor.db" exec "$BIN" serve --addr "127.0.0.1:$MONITOR_PORT" >"$M/monitor.log" 2>&1) &
PIDS="$PIDS $!"
wait_for "$SBM_E2E_MONITOR_ADDR/api/v1/health"

for remote in webdav monitor; do
    echo "== The app against $remote"
    SBM_E2E_BACKUP_REMOTE=$remote SBM_E2E_BACKUP_OUT="$WORK/$remote.age" \
        flutter test --timeout 300s test/e2e/backup_sync_test.dart

    echo "== Opened with the age CLI"
    BACKUP_PASSWORD=$BACKUP_PASSWORD IN="$WORK/$remote.age" OUT="$WORK/$remote.gz" expect -c '
        log_user 0
        spawn age -d -o $env(OUT) $env(IN)
        expect "passphrase"
        send "$env(BACKUP_PASSWORD)\r"
        expect eof
        catch wait result
        exit [lindex $result 3]'
    gunzip -c "$WORK/$remote.gz" | python3 -c 'import json,sys; v=json.load(sys.stdin); assert v["settings"]["timeOut"] == 17, v["settings"].get("timeOut"); print("timeOut", v["settings"]["timeOut"])'
done

echo "== All passed"
