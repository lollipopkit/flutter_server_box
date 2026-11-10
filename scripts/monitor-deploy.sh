#!/usr/bin/env bash
# Put this checkout's Monitor agent and panel on a test machine.
#
#   scripts/monitor-deploy.sh <ssh host> [--no-panel] [--no-agent]
#
# The host keeps a copy of the source in ~/src/flutter_server_box and runs the
# agent from ~/apps/server-box-monitor as the systemd user service
# server-box-monitor (install.sh's layout). The agent is built there with the
# monitor-test profile (minutes, never shipped); the panel is built here.
#
# The panel's files are added, not mirrored: a page opened before this deploy
# still finds the hashed files it names until it reloads (it is told to,
# `/capabilities` `panel_build`). Files of builds older than a week go.
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: $0 <ssh host> [--no-panel] [--no-agent]" >&2; exit 2; }
host=$1
shift
agent=1
panel=1
for arg in "$@"; do
  case $arg in
    --no-agent) agent=0 ;;
    --no-panel) panel=0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

root=$(cd "$(dirname "$0")/.." && pwd)
src='src/flutter_server_box'
app='apps/server-box-monitor'
# The remote login shell may be fish: every remote command is sh's, on stdin.
remote() { printf '%s\n' "$1" | ssh "$host" sh -s; }

if [ "$panel" = 1 ]; then
  echo "==> panel: build"
  (cd "$root/monitor/frontend" && npm run build >/dev/null)
fi

if [ "$agent" = 1 ]; then
  echo "==> agent: sync source to $host:~/$src"
  rsync -az --delete \
    --exclude target --exclude node_modules --exclude build --exclude .dart_tool --exclude .git \
    --exclude 'frontend/dist' --exclude '.claude/worktrees' \
    "$root/" "$host:$src/"
  echo "==> agent: build (monitor-test)"
  remote ". \"\$HOME/.cargo/env\" 2>/dev/null; cd ~/$src && cargo build -p server_box_monitor --profile monitor-test 2>&1 | tail -1"
fi

remote "systemctl --user stop server-box-monitor"
if [ "$agent" = 1 ]; then
  remote "cp ~/$src/target/monitor-test/server_box_monitor ~/$app/server_box_monitor.new && mv ~/$app/server_box_monitor.new ~/$app/server_box_monitor"
fi
if [ "$panel" = 1 ]; then
  echo "==> panel: sync"
  rsync -az "$root/monitor/frontend/dist/" "$host:$app/frontend/dist/"
  remote "find ~/$app/frontend/dist/assets -type f -mtime +7 -delete"
fi
remote "systemctl --user start server-box-monitor && sleep 3 && systemctl --user is-active server-box-monitor"
