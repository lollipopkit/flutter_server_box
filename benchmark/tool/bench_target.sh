#!/usr/bin/env bash
# Prepares an OrbStack Linux machine as the target for the throughput
# benchmarks.
#
# OrbStack's own `<machine>@orb` sshd is not usable here: it is reached through
# an `ssh-proxy-fdpass` ProxyCommand rather than a plain socket, and it ships
# no sftp-server. So this installs a stock OpenSSH server inside the machine
# and talks to it directly on the machine's own IP — both dartssh2 and the
# system ssh/scp then connect the same way, over the same path, with no proxy
# in between. Loopback-class RTT keeps the network from being the variable
# under test.
#
#   ./tool/bench_target.sh up      provision, write .env for the benchmark
#   ./tool/bench_target.sh down    remove the benchmark key from the machine
#   ./tool/bench_target.sh status
set -euo pipefail

MACHINE=${SBM_BENCH_MACHINE:-sbm-debian}
HERE="$(cd "$(dirname "$0")/.." && pwd)"
KEYDIR="$HERE/.bench-keys"
KEY="$KEYDIR/id_ed25519"
ENVFILE="$HERE/.env"
MARKER="sbm-bench-throwaway"

orb_ssh() { ssh -o BatchMode=yes "$MACHINE@orb" "$@"; }

up() {
  if ! orb list 2>/dev/null | awk '{print $1}' | grep -qx "$MACHINE"; then
    echo "OrbStack machine '$MACHINE' not found. Create one, e.g.:" >&2
    echo "  orb create debian $MACHINE" >&2
    exit 1
  fi

  mkdir -p "$KEYDIR"
  chmod 700 "$KEYDIR"
  if [ ! -f "$KEY" ]; then
    ssh-keygen -t ed25519 -N '' -f "$KEY" -C "$MARKER" >/dev/null
  fi

  echo "installing openssh-server in $MACHINE ..."
  orb_ssh 'command -v sshd >/dev/null 2>&1 || {
      sudo apt-get update -qq
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server
    }' >/dev/null

  # sftp-server is what layer 3 exercises; without it SFTP silently degrades.
  if ! orb_ssh 'test -x /usr/lib/openssh/sftp-server'; then
    echo "sftp-server missing after install — aborting" >&2
    exit 1
  fi

  echo "authorising benchmark key ..."
  # shellcheck disable=SC2029
  orb_ssh "mkdir -p ~/.ssh && chmod 700 ~/.ssh &&
    grep -qF '$MARKER' ~/.ssh/authorized_keys 2>/dev/null ||
    echo '$(cat "$KEY.pub")' >> ~/.ssh/authorized_keys;
    chmod 600 ~/.ssh/authorized_keys"

  orb_ssh 'sudo systemctl enable --now ssh >/dev/null 2>&1 ||
           sudo service ssh start >/dev/null 2>&1 || true'

  local ip
  ip=$(orb_ssh "hostname -I | awk '{print \$1}'" | tr -d '\r')
  if [ -z "$ip" ]; then
    echo "could not determine machine IP" >&2
    exit 1
  fi

  local user
  user=$(orb_ssh 'id -un' | tr -d '\r')

  echo "verifying direct connection to $ip:22 ..."
  for _ in $(seq 1 20); do
    if ssh -q -i "$KEY" -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 \
        -o BatchMode=yes -o IdentitiesOnly=yes \
        "$user@$ip" true 2>/dev/null; then
      break
    fi
    sleep 1
  done

  if ! ssh -q -i "$KEY" -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 \
      -o BatchMode=yes -o IdentitiesOnly=yes \
      "$user@$ip" true 2>/dev/null; then
    echo "direct SSH to $user@$ip failed" >&2
    orb_ssh 'sudo journalctl -u ssh --no-pager -n 20' >&2 || true
    exit 1
  fi

  cat > "$ENVFILE" <<EOF
# Written by tool/bench_target.sh — OrbStack machine '$MACHINE', throwaway key.
SBM_BENCH_HOST=$ip
SBM_BENCH_PORT=22
SBM_BENCH_USER=$user
SBM_BENCH_KEY=$KEY
SBM_BENCH_SSH_DEST=$user@$ip
EOF

  echo "ready — $user@$ip, wrote $ENVFILE"
  echo "run: dart run bin/ssh_bench.dart"
}

down() {
  orb_ssh "test -f ~/.ssh/authorized_keys &&
    sed -i '/$MARKER/d' ~/.ssh/authorized_keys" 2>/dev/null || true
  rm -f "$ENVFILE"
  echo "revoked benchmark key on $MACHINE"
}

status() {
  orb list 2>/dev/null | grep -E "^$MACHINE" || echo "$MACHINE not found"
  [ -f "$ENVFILE" ] && echo "env: $ENVFILE" || echo "env: not provisioned"
}

case "${1:-up}" in
  up) up ;;
  down) down ;;
  status) status ;;
  *) echo "usage: $0 {up|down|status}" >&2; exit 2 ;;
esac
