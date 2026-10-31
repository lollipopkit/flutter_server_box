#!/bin/sh
# The monitor agent upgrading itself from its own terminal, on a fresh
# Proxmox VE VM made and destroyed for the run (`scripts/e2e-vm.sh`):
#
#   scripts/monitor-upgrade-e2e.sh <node>
#
# Builds the agent on SBM_E2E_BUILD_HOST (lkd-wsl) and the panel here, packs
# them as a release is packed, and for each form `install.sh` installs —
# a `systemctl --user` service, then the system one — installs it, has the
# agent update itself through its API (`POST /update/run`, as the panel and
# the app do; `monitor-upgrade-e2e.py` follows it across the restart) from
# this checkout's install.sh and package (`SBM_INSTALLER`, `SBM_INSTALL_PKG`
# in a unit drop-in), and checks that it came back as a new process with the
# new files in place. The panel password is read on the VM and never leaves
# it. SBM_E2E_KEEP=1 keeps the VM.
set -eu

node=${1:-}
[ -n "$node" ] || { sed -n '2,14p' "$0" >&2; exit 2; }
build=${SBM_E2E_BUILD_HOST:-lkd-wsl}
root=$(cd "$(dirname "$0")/.." && pwd)
src='src/flutter_server_box'
lab="$root/scripts/e2e-vm.sh"
work=$(mktemp -d)
remote() { printf '%s\n' "$1" | ssh "$build" sh -s; }

echo "==> build: agent on $build"
rsync -az --delete \
  --exclude target --exclude node_modules --exclude build --exclude .dart_tool --exclude .git \
  --exclude 'frontend/dist' --exclude '.claude/worktrees' \
  "$root/" "$build:$src/"
remote ". \"\$HOME/.cargo/env\" 2>/dev/null; cd ~/$src && cargo build -q -p server_box_monitor --profile monitor-test --target x86_64-unknown-linux-musl"
echo "==> build: panel, package"
(cd "$root/monitor/frontend" && npm run build >/dev/null)
pkg="$work/server-box-monitor"
mkdir -p "$pkg/frontend"
scp -q "$build:$src/target/x86_64-unknown-linux-musl/monitor-test/server_box_monitor" "$pkg/"
cp -r "$root/monitor/frontend/dist" "$pkg/frontend/dist"
cp -r "$root/monitor/migrations" "$pkg/migrations"
cp "$root/monitor/config.example.toml" "$root/monitor/.env.example" "$pkg/"
COPYFILE_DISABLE=1 tar --no-xattrs -C "$work" -czf "$work/pkg.tar.gz" server-box-monitor

echo "==> vm: up"
set -- $("$lab" up "$node" | tail -n 1)
id=$1
addr=$2
case $id in '' | *[!0-9]*) echo "the VM did not come up" >&2; exit 1 ;; esac
cleanup() {
  if [ "${SBM_E2E_KEEP:-}" = 1 ]; then echo "==> vm $id kept at $addr"; else "$lab" down "$node" "$id" >/dev/null && echo "==> vm $id destroyed"; fi
  rm -rf "$work"
}
trap cleanup EXIT INT TERM
vm() { ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "root@$addr" "$@"; }
scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$work/pkg.tar.gz" "$root/monitor/install.sh" "$root/scripts/monitor-upgrade-e2e.py" "root@$addr:/tmp/"
vm 'chmod 644 /tmp/pkg.tar.gz /tmp/install.sh /tmp/monitor-upgrade-e2e.py'

# <as> <app dir> <pid command> <drop-in dir> <systemctl>: point the agent at
# the local installer, have it update itself, check it came back.
upgrade() {
  as=$1 dir=$2 pid=$3 dropin=$4 ctl=$5
  vm "mkdir -p $dropin && printf '[Service]\nEnvironment=SBM_INSTALLER=/tmp/install.sh\nEnvironment=SBM_INSTALL_PKG=/tmp/pkg.tar.gz\n' > $dropin/e2e.conf && chmod -R a+rX $dropin"
  vm "$as $ctl daemon-reload && $as $ctl restart server_box_monitor.service"
  vm "i=0; until [ -f $dir/initial-admin-credentials.txt ] || [ \$i -gt 30 ]; do i=\$((i+1)); sleep 1; done; sleep 2"
  before=$(vm "$as $pid")
  echo "    running as pid $before; updating itself"
  vm "$as python3 /tmp/monitor-upgrade-e2e.py $dir" || { echo "FAIL: the update did not finish" >&2; exit 1; }
  vm "i=0; until $as curl -s -o /dev/null http://127.0.0.1:3770/api/v1/health || [ \$i -gt 30 ]; do i=\$((i+1)); sleep 1; done"
  after=$(vm "$as $pid")
  [ -n "$after" ] && [ "$after" != 0 ] && [ "$after" != "$before" ] || { echo "FAIL: the agent did not come back (pid $before -> $after)" >&2; exit 1; }
  left=$(vm "ls -A $dir | grep -E '^\.(server_box_monitor|frontend|migrations)\.(new|old)$' || true")
  [ -z "$left" ] || { echo "FAIL: left behind: $left" >&2; exit 1; }
  vm "test -f $dir/frontend/dist/index.html && test -d $dir/migrations" || { echo "FAIL: files missing" >&2; exit 1; }
  echo "    back as pid $after"
}

echo "==> vm $id: a user service"
vm 'useradd -m -s /bin/bash sbm && loginctl enable-linger sbm; u=$(id -u sbm); i=0; until [ -S /run/user/$u/bus ] || [ $i -gt 20 ]; do i=$((i+1)); sleep 1; done'
user="runuser -u sbm -- env XDG_RUNTIME_DIR=/run/user/\$(id -u sbm)"
vm "cd /tmp && $user SBM_INSTALL_PKG=/tmp/pkg.tar.gz sh /tmp/install.sh install" | tail -n 2
upgrade "$user" /home/sbm/.local/share/server-box-monitor "systemctl --user show -p MainPID --value server_box_monitor.service" \
  /home/sbm/.config/systemd/user/server_box_monitor.service.d "systemctl --user"
vm "cd /tmp && $user sh /tmp/install.sh uninstall </dev/null" | tail -n 1

echo "==> vm $id: the system service"
vm 'cd /tmp && SBM_INSTALL_PKG=/tmp/pkg.tar.gz sh /tmp/install.sh install --system' | tail -n 2
upgrade "env" /opt/server-box-monitor "systemctl show -p MainPID --value server_box_monitor.service" \
  /etc/systemd/system/server_box_monitor.service.d systemctl
echo "==> passed"
