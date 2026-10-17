#!/bin/sh
# A panel end-to-end test that changes the machine itself, on a fresh
# Proxmox VE VM made and destroyed for the run (`scripts/e2e-vm.sh`; its
# template once with `scripts/e2e-vm.sh template <node>`):
#
#   scripts/desk-vm-e2e.sh <node> kernel       # restarts the VM twice
#   scripts/desk-vm-e2e.sh <node> ubuntu_pro   # SBM_E2E_PRO_TOKEN to attach
#   scripts/desk-vm-e2e.sh <node> cleanup      # junk of each kind made first
#   scripts/desk-vm-e2e.sh <node> cleanup_app  # the same, Cleanup as a package
#   scripts/desk-vm-e2e.sh <node> tailscale    # Headscale and a peer made first
#
# Builds the agent on SBM_E2E_BUILD_HOST (lkd-wsl) and the panel here;
# starts a VM; runs the agent there as an ordinary account with a sudo
# password, a systemd user service started at boot, over TLS with a
# self-signed certificate; then runs frontend/e2e/<spec>.e2e.ts against it.
# A `<name>_app` spec gets the package of `monitor/apps/<name>`, built here
# (`scripts/build-desk-app.sh`), as SBM_E2E_APP_PACKAGE.
# For `kernel` it picks a version of the running kernel's flavour older than
# it (SBM_E2E_KERNEL_VERSION). The passwords are made for the run and never
# leave environment variables. SBM_E2E_KEEP=1 keeps the VM.
set -eu

node=${1:-}
spec=${2:-}
[ -n "$node" ] && [ -f "$(dirname "$0")/../monitor/frontend/e2e/$spec.e2e.ts" ] || { sed -n '2,18p' "$0" >&2; exit 2; }
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
case $spec in *_app)
  echo "==> build: package ${spec%_app}"
  SBM_E2E_APP_PACKAGE=$("$root/scripts/build-desk-app.sh" "${spec%_app}" | tail -n 1 | cut -d' ' -f1)
  export SBM_E2E_APP_PACKAGE ;;
esac

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

if [ "$spec" = cleanup ] || [ "$spec" = cleanup_app ]; then
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

if [ "$spec" = tailscale ]; then
# A tailnet of its own: Headscale on the VM and a second, userspace
# tailscaled as the peer (offering an exit node and a route, approved).
# Both pinned and checked here; the machine's Tailscale is the app's to
# install. Nothing reaches a real tailnet.
echo "==> vm $id: headscale and a peer"
hs=0.29.4 hs_sha=212ed0a884c0d3541e094c4bebbe94397df6f4e01bd3d7f059c520cb55e0d757
tsv=1.102.5 ts_sha=65e6d7f19ad7e1c87d20c2a21e92f38a96795cb897af54b04536590e1c148d12
curl -fsSL -o "$work/headscale" "https://github.com/juanfont/headscale/releases/download/v$hs/headscale_${hs}_linux_amd64"
curl -fsSL -o "$work/ts.tgz" "https://pkgs.tailscale.com/stable/tailscale_${tsv}_amd64.tgz"
curl -fsSL -o "$work/headscale.yaml" "https://raw.githubusercontent.com/juanfont/headscale/v$hs/config-example.yaml"
printf '%s  %s\n%s  %s\n' "$hs_sha" "$work/headscale" "$ts_sha" "$work/ts.tgz" | shasum -a 256 -c - >/dev/null
python3 - "$work/headscale.yaml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"(?m)^  urls:\n(    - .*\n)+", "  urls: []\n", s)
s = s.replace("  paths: []", "  paths:\n    - /etc/headscale/derp.yaml", 1)
s = s.replace("  auto_update_enabled: true", "  auto_update_enabled: false").replace("  override_local_dns: true", "  override_local_dns: false")
s = s.replace("base_domain: example.com", "base_domain: e2e.test")
open(p, "w").write(s)
PY
scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$work/headscale" "$work/ts.tgz" "$work/headscale.yaml" "root@$addr:/tmp/"
SBM_E2E_TS_KEY=$(vm 'set -e
  install -m 755 /tmp/headscale /usr/local/bin/headscale; mkdir -p /etc/headscale /var/lib/headscale /opt/ts-peer /var/lib/ts-peer /run/ts-peer
  mv /tmp/headscale.yaml /etc/headscale/config.yaml
  # A relay nobody reaches: both nodes are on this machine and talk directly.
  printf "regions:\n  900:\n    regionid: 900\n    regioncode: none\n    regionname: None\n    nodes:\n      - name: 900a\n        regionid: 900\n        hostname: derp.invalid\n        stunport: -1\n        derpport: 0\n" > /etc/headscale/derp.yaml
  tar -xzf /tmp/ts.tgz -C /opt/ts-peer --strip-components=1
  systemd-run --unit=sbm-headscale /usr/local/bin/headscale serve >/dev/null
  i=0; until headscale users list >/dev/null 2>&1 || [ $i -gt 20 ]; do i=$((i+1)); sleep 1; done
  headscale users create e2e >/dev/null
  key=$(headscale preauthkeys create --user 1 --reusable --expiration 2h 2>/dev/null | tail -n 1)
  systemd-run --unit=sbm-ts-peer /opt/ts-peer/tailscaled --tun=userspace-networking --socket=/run/ts-peer/s.sock --statedir=/var/lib/ts-peer --port=41642 >/dev/null
  sleep 2
  /opt/ts-peer/tailscale --socket=/run/ts-peer/s.sock up --login-server=http://127.0.0.1:8080 --auth-key="$key" --hostname=peer --advertise-exit-node --advertise-routes=10.99.0.0/24 --timeout=60s >/dev/null
  headscale nodes approve-routes --identifier 1 --routes 0.0.0.0/0,::/0,10.99.0.0/24 >/dev/null
  printf %s "$key"')
[ -n "$SBM_E2E_TS_KEY" ] || { echo "headscale gave no key" >&2; exit 1; }
export SBM_E2E_TS_KEY SBM_E2E_TS_SERVER=http://127.0.0.1:8080
export SBM_E2E_TS_REGISTER="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@$addr headscale auth register --user e2e --auth-id"
fi

cd "$root/monitor/frontend"
echo "==> $spec.e2e.ts"
SBM_E2E_CLEANUP=1 npx playwright test "/$spec.e2e.ts" --reporter=line --output="e2e/.results/$spec"
echo "==> all passed"
