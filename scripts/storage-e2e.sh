#!/bin/sh
# The Storage and Sharing end-to-end tests on a fresh Proxmox VE VM, made
# and destroyed for the run (`scripts/e2e-vm.sh`; its template once with
# `scripts/e2e-vm.sh template <node>`):
#
#   scripts/storage-e2e.sh <node>
#
# Builds the agent and the Rust e2e binaries on SBM_E2E_BUILD_HOST (lkd-wsl,
# an x86_64 Linux with Rust) and the panel here; starts a VM with four empty
# disks; runs the agent there as an ordinary account with a sudo password;
# then, against it:
#   1. frontend/e2e/storage.e2e.ts  (Playwright, the disks)
#   2. frontend/e2e/sharing.e2e.ts  (Playwright; installs Samba and NFS)
#   3. tests/storage_e2e.rs          (root, loop devices)
#   4. tests/shares_e2e.rs           (root)
# The account's sudo password and the panel's admin password are made for
# the run and never leave environment variables. SBM_E2E_KEEP=1 keeps the VM.
set -eu

node=${1:-}
[ -n "$node" ] || { sed -n '2,19p' "$0" >&2; exit 2; }
build=${SBM_E2E_BUILD_HOST:-lkd-wsl}
root=$(cd "$(dirname "$0")/.." && pwd)
src='src/flutter_server_box'
lab="$root/scripts/e2e-vm.sh"
work=$(mktemp -d)
remote() { printf '%s\n' "$1" | ssh "$build" sh -s; }

echo "==> build: agent and e2e binaries on $build"
rsync -az --delete \
  --exclude target --exclude node_modules --exclude build --exclude .dart_tool --exclude .git \
  --exclude 'frontend/dist' --exclude '.claude/worktrees' \
  "$root/" "$build:$src/"
remote ". \"\$HOME/.cargo/env\" 2>/dev/null; cd ~/$src && cargo build -q -p server_box_monitor --profile monitor-test && \
  cargo test -p server_box_monitor --test storage_e2e --test shares_e2e --no-run 2>&1 | sed -n 's/.*Executable .*(\(.*\))/\1/p'" > "$work/tests"
storage_test="$src/$(grep storage_e2e "$work/tests")"
shares_test="$src/$(grep shares_e2e "$work/tests")"
echo "==> build: panel"
(cd "$root/monitor/frontend" && npm run build >/dev/null)

echo "==> vm: up"
set -- $("$lab" up "$node" 4 | tail -n 1)
id=$1
addr=$2
case $id in '' | *[!0-9]*) echo "the VM did not come up" >&2; exit 1 ;; esac
tunnel="$work/tunnel"
cleanup() {
  ssh -S "$tunnel" -O exit "root@$addr" 2>/dev/null || true
  if [ "${SBM_E2E_KEEP:-}" = 1 ]; then echo "==> vm $id kept at $addr"; else "$lab" down "$node" "$id" >/dev/null && echo "==> vm $id destroyed"; fi
  rm -rf "$work"
}
trap cleanup EXIT INT TERM
vm() { ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "root@$addr" "$@"; }

echo "==> vm $id: agent as an ordinary account"
SBM_E2E_SUDO_PASSWORD=$(openssl rand -hex 16)
export SBM_E2E_SUDO_PASSWORD
printf '%s\n' "$SBM_E2E_SUDO_PASSWORD" | vm 'read -r p; useradd -m -s /bin/bash -G sudo sbm && echo "sbm:$p" | chpasswd && loginctl enable-linger sbm \
  && mkdir -p /home/sbm/app/frontend /home/sbm/.config/systemd/user /srv/share && chown sbm /srv/share'
scp -q -3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$build:$src/target/monitor-test/server_box_monitor" "$build:$storage_test" "$build:$shares_test" "root@$addr:/home/sbm/app/"
COPYFILE_DISABLE=1 tar --no-xattrs -C "$root/monitor/frontend" -czf - dist | vm 'tar -C /home/sbm/app/frontend -xzf -'
vm "cat > /home/sbm/.config/systemd/user/sbm.service <<'EOF'
[Service]
WorkingDirectory=%h/app
ExecStart=%h/app/server_box_monitor serve -a 127.0.0.1:3770
Environment=SBM_INIT_PERMISSIONS=full
[Install]
WantedBy=default.target
EOF
chown -R sbm: /home/sbm; u=\$(id -u sbm); i=0; until [ -S /run/user/\$u/bus ] || [ \$i -gt 20 ]; do i=\$((i+1)); sleep 1; done
runuser -u sbm -- env XDG_RUNTIME_DIR=/run/user/\$u systemctl --user daemon-reload
runuser -u sbm -- env XDG_RUNTIME_DIR=/run/user/\$u systemctl --user start sbm
i=0; until [ -f /home/sbm/app/initial-admin-credentials.txt ] || [ \$i -gt 30 ]; do i=\$((i+1)); sleep 1; done"
SBM_E2E_PANEL_PASSWORD=$(vm "awk '/^password:/{print \$2}' /home/sbm/app/initial-admin-credentials.txt")
export SBM_E2E_PANEL_PASSWORD
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
ssh -M -S "$tunnel" -fN -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ExitOnForwardFailure=yes \
  -L "$port:127.0.0.1:3770" "root@$addr"
export SBM_E2E_PANEL_URL="http://127.0.0.1:$port"
SBM_E2E_STORAGE_DISKS=$(vm "lsblk -dn -o PATH,SERIAL | awk '\$2 ~ /^sbmdisk/ { print \$1 }' | paste -sd, -")
export SBM_E2E_STORAGE_DISKS SBM_E2E_SHARE_FOLDER=/srv/share SBM_E2E_SHARE_ACCOUNT=sbm

failed=''
step() {
  name=$1
  shift
  echo "==> $name"
  if "$@"; then echo "    ok"; else echo "    FAILED"; failed="$failed $name"; fi
}
cd "$root/monitor/frontend"
step storage.e2e.ts npx playwright test storage --reporter=line
step sharing.e2e.ts npx playwright test sharing --reporter=line
rust() {
  vm "cd /home/sbm/app && out=\$($1=1 RUST_LOG=off ./$2 --ignored 2>&1); code=\$?; printf '%s\n' \"\$out\" | grep -E -A6 'test result|panicked|is not set'; exit \$code"
}
step storage_e2e.rs rust SBM_E2E_STORAGE "$(basename "$storage_test")"
step shares_e2e.rs rust SBM_E2E_SHARES "$(basename "$shares_test")"

if [ -n "$failed" ]; then echo "==> failed:$failed"; exit 1; fi
echo "==> all passed"
