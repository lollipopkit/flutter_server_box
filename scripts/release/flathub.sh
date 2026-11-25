#!/usr/bin/env bash
# Render and validate the Flathub submission files from
# linux/packaging/flatpak/.
#
#   flathub.sh release <version> <dir>  renders from a published GitHub release
#   flathub.sh render <dir>             renders from URL and SHA256 env vars
#   flathub.sh check <dir>              validates manifest, flathub.json, and
#                                       upstream desktop/metainfo metadata
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/linux/packaging/flatpak"
APP_ID="tech.lolli.toolbox"
REPO="lollipopkit/flutter_server_box"
APP_NAME="ServerBox"

render() {
  local out="$1"
  : "${URL:?}" "${SHA256:?}"
  mkdir -p "$out"
  # shellcheck disable=SC2016 # envsubst variable list; keep ${FLATPAK_ID} intact
  envsubst '${URL} ${SHA256}' \
    < "$TEMPLATE_DIR/${APP_ID}.yml" \
    > "$out/${APP_ID}.yml"
  cp "$TEMPLATE_DIR/flathub.json" "$out/flathub.json"
}

release() {
  local version="$1" out="$2" name
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "invalid version '$version' (expected X.Y.Z without leading v)" >&2
    return 1
  }
  name="${APP_NAME}_v${version}_linux_amd64.tar.gz"
  URL="https://github.com/$REPO/releases/download/v$version/$name"
  SHA256="$(gh release download "v$version" --repo "$REPO" -p SHA256SUMS -O - |
    awk -v f="$name" '$2 == f || $2 == "*" f { print $1 }')"
  [[ "$SHA256" =~ ^[0-9a-f]{64}$ ]] || {
    echo "no checksum for $name in v$version SHA256SUMS" >&2
    return 1
  }
  export URL SHA256
  render "$out"
}

check() {
  local dir="$1"
  local manifest="$dir/${APP_ID}.yml"
  local flathub_json="$dir/flathub.json"

  [[ -f "$manifest" ]] || { echo "::error::missing $manifest" >&2; return 1; }
  [[ -f "$flathub_json" ]] || { echo "::error::missing $flathub_json" >&2; return 1; }

  # shellcheck disable=SC2016 # literal placeholder names
  if grep -nE '\$\{(URL|SHA256)\}' "$manifest"; then
    echo "::error file=$manifest::unrendered template placeholder" >&2
    return 1
  fi
  # shellcheck disable=SC2016 # runtime variable expanded by flatpak-builder
  if ! grep -Fq '${FLATPAK_ID}' "$manifest"; then
    echo "::error file=$manifest::missing \${FLATPAK_ID} references (check envsubst variable list)" >&2
    return 1
  fi

  python3 - "$manifest" "$flathub_json" "$APP_ID" <<'PY'
import json
import re
import sys

manifest_path, flathub_json_path, app_id = sys.argv[1:4]

with open(flathub_json_path, encoding="utf-8") as f:
    cfg = json.load(f)
if cfg.get("only-arches") != ["x86_64"]:
    sys.exit(f"unexpected only-arches in {flathub_json_path}: {cfg!r}")

with open(manifest_path, encoding="utf-8") as f:
    text = f.read()

try:
    import yaml  # type: ignore
except ImportError:
    yaml = None

if yaml is not None:
    data = yaml.safe_load(text)
    if data.get("app-id") != app_id:
        sys.exit(f"app-id mismatch: {data.get('app-id')!r}")
    if data.get("command") != "serverbox":
        sys.exit(f"command mismatch: {data.get('command')!r}")
    sources = data["modules"][0]["sources"]
    archive = sources[0]
    if archive.get("type") != "archive":
        sys.exit(f"expected archive source, got: {archive.get('type')!r}")
    url = archive.get("url", "")
    sha = archive.get("sha256", "")
    if not isinstance(url, str) or not url.startswith("https://") or not url.endswith("_linux_amd64.tar.gz"):
        sys.exit(f"unexpected archive url: {url!r}")
    if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{64}", sha):
        sys.exit(f"invalid sha256: {sha!r}")
    checker = archive.get("x-checker-data", {})
    if checker.get("type") != "json":
        sys.exit(f"expected json x-checker-data, got: {checker!r}")
else:
    if f"app-id: {app_id}" not in text:
        sys.exit("app-id line missing")
    if not re.search(r"^\s*sha256:\s*'?[0-9a-f]{64}'?\s*$", text, re.M):
        sys.exit("valid sha256 line missing")
    if not re.search(r"^\s*url:\s*https://\S+_linux_amd64\.tar\.gz\s*$", text, re.M):
        sys.exit("valid archive url line missing")
PY

  if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$REPO_ROOT/linux/packaging/${APP_ID}.desktop"
  fi

  if command -v appstreamcli >/dev/null 2>&1; then
    appstreamcli validate --pedantic --no-net "$REPO_ROOT/linux/packaging/${APP_ID}.metainfo.xml"
  fi

  if command -v flatpak-builder-lint >/dev/null 2>&1; then
    flatpak-builder-lint manifest "$manifest"
  fi
}

cmd="${1:-}"
shift || true
case "$cmd" in
  render)  [[ $# -eq 1 ]] || { echo "usage: $0 render <dir>" >&2; exit 2; }; render "$1" ;;
  release) [[ $# -eq 2 ]] || { echo "usage: $0 release <version> <dir>" >&2; exit 2; }; release "$1" "$2" ;;
  check)   [[ $# -eq 1 ]] || { echo "usage: $0 check <dir>" >&2; exit 2; }; check "$1" ;;
  *)
    echo "usage: $0 <render|release|check> ..." >&2
    exit 2
    ;;
esac
