#!/bin/sh
# The app's backup sync end to end, on this machine (issue #1772):
#
# 1. rclone's WebDAV started on loopback with a random account;
# 2. `test/e2e/backup_sync_test.dart` against it: the upload is sealed to
#    the sync key under the v5 name, another device restores it, a device on
#    another password syncs nothing, a v4- or v3-only remote is inherited and
#    moved to v5;
# 3. the key file opened with the `age` CLI and the backup password, nothing
#    of ServerBox's, and the backup with that key, and what is in it read;
# 4. `test/e2e/segment_sync_test.dart` against the WebDAV: the log sync's
#    segments reach other devices; the sync key opened with the backup
#    password, and a segment with that key, by the `age` CLI.
#
#     scripts/app-backup-e2e.sh
#
# Needs rclone, htpasswd, age, expect and flutter. Secrets are generated here
# and passed through the environment.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sbm-app-backup-e2e.XXXXXX")
WEBDAV_PORT=18090
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
export SBM_E2E_WEBDAV_PASSWORD
export SBM_E2E_WEBDAV_URL="http://127.0.0.1:$WEBDAV_PORT/"

wait_for() { # url
    i=0
    until curl -s --noproxy '*' -o /dev/null "$1"; do
        i=$((i + 1)); [ "$i" -lt 150 ] || { echo "no answer from $1" >&2; exit 1; }
        sleep 0.2
    done
}

# The key file opened with the password, as `age -d` asks for it: IN, OUT.
open_key() {
    BACKUP_PASSWORD=$BACKUP_PASSWORD IN=$1 OUT=$2 expect -c '
        log_user 0
        spawn age -d -o $env(OUT) $env(IN)
        expect "passphrase"
        send "$env(BACKUP_PASSWORD)\r"
        expect eof
        catch wait result
        exit [lindex $result 3]'
}

echo "== WebDAV"
mkdir -p "$WORK/rclone" "$WORK/backup"
printf '%s' "$SBM_E2E_WEBDAV_PASSWORD" | htpasswd -iBc "$WORK/htpasswd" "$SBM_E2E_WEBDAV_USER" 2>/dev/null
# An empty config: the user's own may be encrypted and ask for its password.
: >"$WORK/rclone.conf"
rclone --config "$WORK/rclone.conf" serve webdav --addr "127.0.0.1:$WEBDAV_PORT" --htpasswd "$WORK/htpasswd" "$WORK/rclone" >"$WORK/rclone.log" 2>&1 &
PIDS="$PIDS $!"
wait_for "$SBM_E2E_WEBDAV_URL"

cd "$ROOT"
echo "== The app against webdav"
SBM_E2E_BACKUP_OUT="$WORK/backup" flutter test --timeout 300s test/e2e/backup_sync_test.dart

echo "== Its key and the backup opened with the age CLI"
open_key "$WORK/backup/identity.age" "$WORK/backup/identity.txt"
age -d -i "$WORK/backup/identity.txt" "$WORK/backup/backup.age" | gunzip -c |
    python3 -c 'import json,sys; v=json.load(sys.stdin); assert v["settings"]["timeOut"] == 17, v["settings"].get("timeOut"); print("timeOut", v["settings"]["timeOut"])'

echo "== The log sync against webdav"
mkdir -p "$WORK/segments"
SBM_E2E_SEGMENT_OUT="$WORK/segments" flutter test --timeout 300s test/e2e/segment_sync_test.dart

echo "== Its key and a segment opened with the age CLI"
open_key "$WORK/segments/identity.age" "$WORK/segments/identity.txt"
for seg in "$WORK"/segments/seg-*.age; do
    age -d -i "$WORK/segments/identity.txt" "$seg" | gunzip -c |
        python3 -c 'import json,sys; v=json.load(sys.stdin); assert isinstance(v.get("v"), int) and v["ops"], "no ops"; print(len(v["ops"]), "ops")'
done

echo "== All passed"
