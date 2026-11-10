#!/bin/sh
# Agent mode's chats encrypted in place, end to end (issue #1773): a monitor
# of a build from before keeps two chats in clear; the build after opens them,
# encrypts each where it lies, keeps every message, takes a reply, and reads
# them all again after a restart.
#
#     scripts/agent-chat-encryption-e2e.sh OLD_BINARY NEW_BINARY
#
# Both run in a folder of their own on loopback, with a model this script
# serves (`agent-chat-encryption-e2e/mock_model.py`): nothing of a running
# monitor is touched. Needs python3, curl and openssl.
set -eu

OLD=$1
NEW=$2
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sbm-chat-e2e.XXXXXX")
PORT=3797
MODEL_PORT=18097
API="http://127.0.0.1:$PORT/api/v1"
PID=""
MODEL=""
cleanup() {
    kill $PID $MODEL 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

SBM_E2E_PANEL_PASSWORD=$(openssl rand -hex 12)
export SBM_E2E_PANEL_PASSWORD

fail() { echo "FAIL: $*" >&2; exit 1; }
json() { python3 -c "import json,sys; v=json.load(sys.stdin); print($1)"; }
wait_for() { # url
    i=0
    until curl -s --noproxy '*' -o /dev/null "$1"; do
        i=$((i + 1)); [ "$i" -lt 150 ] || fail "no answer from $1"
        sleep 0.2
    done
}

# A monitor of [binary] in $WORK, signed in to.
serve() {
    (cd "$WORK" && DATABASE_URL="sqlite://$WORK/monitor.db" exec "$1" serve --addr "127.0.0.1:$PORT" >>"$WORK/monitor.log" 2>&1) &
    PID=$!
    wait_for "$API/health"
    TOKEN=$(curl -sf --noproxy '*' -H 'content-type: application/json' \
        -d "{\"password\":\"$SBM_E2E_PANEL_PASSWORD\"}" "$API/login" | json 'v["token"]')
}
stop() {
    kill "$PID"
    wait "$PID" 2>/dev/null || true
    PID=""
}
call() { # method path [body]
    curl -sf --noproxy '*' -X "$1" -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
        ${3:+-d "$3"} "$API$2"
}
until_done() { # id
    i=0
    until [ "$(call GET "/agent/flows/$1" | json 'v["flow"]["status"]')" = done ]; do
        i=$((i + 1)); [ "$i" -lt 300 ] || fail "task $1 never finished"
        sleep 0.1
    done
}
start() { # prompt -> id
    id=$(call POST /agent/flows "{\"prompt\":\"$1\"}" | json 'v["id"]')
    until_done "$id"
    echo "$id"
}
# The model's answers in the task, as one line.
answers() { # id
    call GET "/agent/flows/$1" | python3 -c '
import json, re, sys
print(" | ".join(re.findall(r"Answer to: [^\"\\]*", json.dumps(json.load(sys.stdin)["entries"]))))'
}
in_clear() { # id: whether its chat file is a plain SQLite file
    [ "$(head -c 15 "$WORK/agent/chats/$1.db")" = "SQLite format 3" ]
}

python3 "$HERE/agent-chat-encryption-e2e/mock_model.py" "$MODEL_PORT" &
MODEL=$!
wait_for "http://127.0.0.1:$MODEL_PORT/v1/models"

echo "== The build before: chats in clear"
(cd "$WORK" && DATABASE_URL="sqlite://$WORK/monitor.db" "$OLD" password --password-env SBM_E2E_PANEL_PASSWORD >/dev/null)
serve "$OLD"
call PUT /agent/settings "{\"model\":{\"provider\":\"mock\",\"id\":\"mock\"},\"providers\":[{\"id\":\"mock\",\"name\":\"Mock\",\"api\":\"openai-completions\",\"baseUrl\":\"http://127.0.0.1:$MODEL_PORT/v1\",\"models\":[{\"id\":\"mock\"}]}],\"credentials\":{\"mock\":\"sk-e2e\"}}" >/dev/null
A=$(start "first question")
B=$(start "second question")
A_BEFORE=$(answers "$A")
B_BEFORE=$(answers "$B")
[ "$A_BEFORE" = "Answer to: first question" ] || fail "chat A before: $A_BEFORE"
[ "$B_BEFORE" = "Answer to: second question" ] || fail "chat B before: $B_BEFORE"
stop
in_clear "$A" && in_clear "$B" || fail "the build before did not keep its chats in clear: pick an older OLD_BINARY"

echo "== The build after: encrypted in place"
serve "$NEW"
[ "$(answers "$A")" = "$A_BEFORE" ] || fail "chat A after: $(answers "$A")"
[ "$(answers "$B")" = "$B_BEFORE" ] || fail "chat B after: $(answers "$B")"
call POST "/agent/flows/$A/reply" '{"text":"a follow-up"}' >/dev/null
until_done "$A"
A_AFTER=$(answers "$A")
[ "$A_AFTER" = "Answer to: first question | Answer to: a follow-up" ] || fail "chat A replied: $A_AFTER"
C=$(start "third question")
stop
for id in "$A" "$B" "$C"; do
    in_clear "$id" && fail "chat $id is still in clear"
done

echo "== After a restart"
serve "$NEW"
[ "$(answers "$A")" = "$A_AFTER" ] || fail "chat A after a restart: $(answers "$A")"
[ "$(answers "$B")" = "$B_BEFORE" ] || fail "chat B after a restart: $(answers "$B")"
[ "$(answers "$C")" = "Answer to: third question" ] || fail "chat C after a restart: $(answers "$C")"
stop

echo "== All passed"
