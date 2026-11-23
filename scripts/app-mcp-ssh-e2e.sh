#!/usr/bin/env bash
# From the repository root. The fixture has no Monitor, host mounts or persistent keys.
set -euo pipefail
umask 077
work=$(mktemp -d)
fixture=
monitor_pid=
cleanup() {
  if [[ -n "$monitor_pid" ]]; then kill "$monitor_pid" 2>/dev/null || true; wait "$monitor_pid" || true; fi
  if [[ -n "$fixture" ]]; then docker rm -f "$fixture" >/dev/null || true; fi
  rm -rf -- "$work"
}
trap cleanup EXIT
ssh-keygen -q -t ed25519 -N '' -f "$work/client"
fixture=$(docker run -d -p 127.0.0.1::22 alpine:3 sleep 1200)
docker exec "$fixture" sh -ec '
  apk add --no-cache openssh-server openssh-keygen >/dev/null
  adduser -D fixture
  passwd -d fixture >/dev/null
  install -d -m 700 -o fixture -g fixture /home/fixture/.ssh
  ssh-keygen -q -t ed25519 -N "" -f /etc/ssh/fixture_key
'
docker exec -i "$fixture" sh -ec 'cat > /home/fixture/.ssh/authorized_keys; chown fixture:fixture /home/fixture/.ssh/authorized_keys; chmod 600 /home/fixture/.ssh/authorized_keys' < "$work/client.pub"
docker exec "$fixture" /usr/sbin/sshd -h /etc/ssh/fixture_key -o AllowTcpForwarding=local -o PermitOpen=127.0.0.1:22 -o PasswordAuthentication=no -o PermitRootLogin=no -o AllowUsers=fixture
port=$(docker port "$fixture" 22/tcp)
fingerprint=$(docker exec "$fixture" cat /etc/ssh/fixture_key.pub | ssh-keygen -lf - | awk '{print $2}')
# Set MCP_MONITOR_BIN to exercise the same stdio client against a real Monitor.
monitor_port=0
if [[ -n "${MCP_MONITOR_BIN:-}" ]]; then
  binary=$(realpath "$MCP_MONITOR_BIN")
  monitor_port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  (cd "$work" && exec "$binary" serve --addr "127.0.0.1:$monitor_port") >"$work/monitor.log" 2>&1 &
  monitor_pid=$!
  for _ in {1..100}; do
    if curl -fsS "http://127.0.0.1:$monitor_port/api/v1/health" >/dev/null 2>&1; then break; fi
    kill -0 "$monitor_pid"
    sleep 0.2
  done
  test -s "$work/initial-admin-credentials.txt"
fi
flutter test --no-pub -d macos \
  --dart-define="MCP_STDIO_SCRIPT=$PWD/scripts/app-mcp-stdio.py" \
  --dart-define="MCP_MONITOR_PORT=$monitor_port" \
  --dart-define="MCP_MONITOR_CREDENTIAL_FILE=$work/initial-admin-credentials.txt" \
  --dart-define="MCP_SSH_PORT=${port##*:}" \
  --dart-define="MCP_SSH_KEY=$work/client" \
  --dart-define="MCP_SSH_HOST_FINGERPRINT=$fingerprint" \
  integration_test/app_mcp_stdio_test.dart
