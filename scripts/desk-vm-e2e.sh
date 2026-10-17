#!/bin/sh
# A panel end-to-end test that changes the machine itself, on a fresh
# Proxmox VE VM made and destroyed for the run (`scripts/e2e-vm.sh`; its
# template once with `scripts/e2e-vm.sh template <node>`):
#
#   scripts/desk-vm-e2e.sh <node> kernel       # restarts the VM twice
#   scripts/desk-vm-e2e.sh <node> ubuntu_pro   # SBM_E2E_PRO_TOKEN to attach
#   scripts/desk-vm-e2e.sh <node> cleanup      # junk of each kind made first
#
# Builds the agent on SBM_E2E_BUILD_HOST (lkd-wsl) and the panel here;
# starts a VM; runs the agent there as an ordinary account with a sudo
# password, a systemd user service started at boot, over TLS with a
# self-signed certificate; then runs frontend/e2e/<spec>.e2e.ts against it.
# For `kernel` it picks a version of the running kernel's flavour older than
# it (SBM_E2E_KERNEL_VERSION). The passwords are made for the run and never
# leave environment variables. SBM_E2E_KEEP=1 keeps the VM.
set -eu

node=${1:-}
spec=${2:-}
[ -n "$node" ] && [ -f "$(dirname "$0")/../monitor/frontend/e2e/$spec.e2e.ts" ] || { sed -n '2,17p' "$0" >&2; exit 2; }
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
remote ". \"\$HOME/.cargo/env\" 2>/dev/null; cd ~/$src && cargo build -q -p server_box_monitor --profile monitor-test"
echo "==> build: panel"
(cd "$root/monitor/frontend" && npm run build >/dev/null)

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

echo "==> vm $id: agent as an ordinary account"
SBM_E2E_SUDO_PASSWORD=$(openssl rand -hex 16)
export SBM_E2E_SUDO_PASSWORD
printf '%s\n' "$SBM_E2E_SUDO_PASSWORD" | vm 'read -r p; useradd -m -s /bin/bash -G sudo sbm && echo "sbm:$p" | chpasswd && loginctl enable-linger sbm \
  && mkdir -p /home/sbm/app/frontend /home/sbm/.config/systemd/user'
scp -q -3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$build:$src/target/monitor-test/server_box_monitor" "root@$addr:/home/sbm/app/"
COPYFILE_DISABLE=1 tar --no-xattrs -C "$root/monitor/frontend" -czf - dist | vm 'tar -C /home/sbm/app/frontend -xzf -'
vm "cd /home/sbm/app && openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 2 -subj /CN=$addr \
  -addext subjectAltName=IP:$addr -keyout tls.key -out tls.crt 2>/dev/null && chmod 600 tls.key
cat > /home/sbm/.config/systemd/user/sbm.service <<'EOF'
[Service]
WorkingDirectory=%h/app
ExecStart=%h/app/server_box_monitor serve -a 0.0.0.0:3770 -c %h/app/tls.crt -k %h/app/tls.key
[Install]
WantedBy=default.target
EOF
chown -R sbm: /home/sbm; u=\$(id -u sbm); i=0; until [ -S /run/user/\$u/bus ] || [ \$i -gt 20 ]; do i=\$((i+1)); sleep 1; done
runuser -u sbm -- env XDG_RUNTIME_DIR=/run/user/\$u systemctl --user daemon-reload
runuser -u sbm -- env XDG_RUNTIME_DIR=/run/user/\$u systemctl --user enable --now sbm
i=0; until [ -f /home/sbm/app/initial-admin-credentials.txt ] || [ \$i -gt 30 ]; do i=\$((i+1)); sleep 1; done"
SBM_E2E_PANEL_PASSWORD=$(vm "awk '/^password:/{print \$2}' /home/sbm/app/initial-admin-credentials.txt")
export SBM_E2E_PANEL_PASSWORD SBM_E2E_PANEL_URL="https://$addr:3770"

if [ "$spec" = kernel ]; then
# The newest version of the running flavour older than it.
SBM_E2E_KERNEL_VERSION=$(vm 'apt-get update -q >/dev/null 2>&1; r=$(uname -r); f=${r#*-*-}
  apt list "linux-image-*-$f" 2>/dev/null | sed -n "s,^linux-image-\([0-9][^/]*-$f\)/.*,\1,p" | sort -V | awk -v r="$r" "\$0 == r { exit } { v = \$0 } END { print v }"')
[ -n "$SBM_E2E_KERNEL_VERSION" ] || { echo "no older kernel of the running flavour is offered" >&2; exit 1; }
export SBM_E2E_KERNEL_VERSION
echo "==> vm $id: $(vm uname -r) running, $SBM_E2E_KERNEL_VERSION to install"
fi

if [ "$spec" = cleanup ]; then
# Something of each kind to clean: a downloaded package, one nothing needs,
# old logs, a crash report, the account's trash and caches, and a folder a
# removed web app left (a file in it root's, as a container's would be).
echo "==> vm $id: junk to clean"
vm 'set -e; export DEBIAN_FRONTEND=noninteractive
  apt-get install -y -q cowsay >/dev/null && apt-mark auto cowsay >/dev/null
  apt-get install -y -q --download-only --reinstall sl >/dev/null 2>&1 || apt-get install -y -q --download-only sl >/dev/null
  head -c 2000000 /dev/urandom > /var/log/sbm-e2e.log.1; head -c 1000000 /dev/urandom | gzip > /var/log/sbm-e2e.log.2.gz
  mkdir -p /var/crash; head -c 1500000 /dev/urandom > /var/crash/sbm-e2e.crash
  runuser -u sbm -- sh -c "mkdir -p ~/.cache/sbm-e2e-app ~/.npm/_cacache ~/.local/share/Trash/files ~/.local/share/Trash/info ~/app/stacks/sbm.leftover/data
    head -c 5000000 /dev/urandom > ~/.cache/sbm-e2e-app/blob; head -c 2000000 /dev/urandom > ~/.npm/_cacache/blob
    head -c 1000000 /dev/urandom > ~/.local/share/Trash/files/old; head -c 3000000 /dev/urandom > ~/app/stacks/sbm.leftover/data/db"
  head -c 1000000 /dev/urandom > /home/sbm/app/stacks/sbm.leftover/data/root-owned'
fi

cd "$root/monitor/frontend"
echo "==> $spec.e2e.ts"
SBM_E2E_CLEANUP=1 npx playwright test "$spec" --reporter=line --output="e2e/.results/$spec"
echo "==> all passed"
