#!/usr/bin/env bash
# Package a built Flutter Linux release bundle into:
#   - <APP_NAME>_v<VERSION>_amd64.deb
#   - <APP_NAME>_v<VERSION>_x86_64.rpm
#   - <APP_NAME>_v<VERSION>_linux_amd64.tar.gz (portable bundle + freedesktop
#     metadata; also consumed as the upstream archive by the Flathub manifest)
#
# Usage:
#   scripts/release/package-linux-native.sh \
#     --bundle build/linux/x64/release/bundle \
#     --version 1.0.1962 \
#     --out dist \
#     [--app-name ServerBox] \
#     [--release-date YYYY-MM-DD] \
#     [--skip-nfpm]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP_ID="tech.lolli.toolbox"
APP_NAME="ServerBox"
BUNDLE_DIR=""
VERSION=""
OUT_DIR=""
RELEASE_DATE="$(date -u +%Y-%m-%d)"
SKIP_NFPM=false

usage() {
  cat >&2 <<'EOF'
Usage: package-linux-native.sh --bundle <dir> --version <X.Y.Z> --out <dir> [options]

Options:
  --bundle <dir>         Path to build/linux/x64/release/bundle
  --version <X.Y.Z>      Package version without leading "v" (e.g. 1.0.1962)
  --out <dir>            Output directory for .deb, .rpm, and .tar.gz
  --app-name <name>      Artifact name prefix (default: ServerBox)
  --release-date <date>  Release date YYYY-MM-DD for AppStream metainfo (default: today UTC)
  --skip-nfpm            Only validate metadata and build the .tar.gz archive
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle) [[ $# -ge 2 ]] || usage; BUNDLE_DIR="$2"; shift 2 ;;
    --version) [[ $# -ge 2 ]] || usage; VERSION="$2"; shift 2 ;;
    --out) [[ $# -ge 2 ]] || usage; OUT_DIR="$2"; shift 2 ;;
    --app-name) [[ $# -ge 2 ]] || usage; APP_NAME="$2"; shift 2 ;;
    --release-date) [[ $# -ge 2 ]] || usage; RELEASE_DATE="$2"; shift 2 ;;
    --skip-nfpm) SKIP_NFPM=true; shift ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done

[[ -n "$BUNDLE_DIR" && -n "$VERSION" && -n "$OUT_DIR" ]] || usage
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "::error::invalid version '$VERSION' (expected X.Y.Z without leading v)" >&2
  exit 1
}
[[ "$RELEASE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || {
  echo "::error::invalid release date '$RELEASE_DATE' (expected YYYY-MM-DD)" >&2
  exit 1
}

BUNDLE_DIR="$(cd "$BUNDLE_DIR" && pwd)"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

for required in \
  "$BUNDLE_DIR/$APP_NAME" \
  "$BUNDLE_DIR/lib/libflutter_linux_gtk.so" \
  "$BUNDLE_DIR/data/icudtl.dat"; do
  if [[ ! -e "$required" ]]; then
    echo "::error::missing expected bundle file: $required" >&2
    exit 1
  fi
done
if [[ ! -x "$BUNDLE_DIR/$APP_NAME" ]]; then
  echo "::error::bundle binary is not executable: $BUNDLE_DIR/$APP_NAME" >&2
  exit 1
fi

# Guard against the DT_RUNPATH transitive-lookup trap: bundled tray shared
# libraries (when real ELF binaries rather than CI smoke placeholders) must
# carry `$ORIGIN` in DT_RUNPATH or DT_RPATH so libayatana-appindicator3 can
# resolve libdbusmenu-gtk3.so.4 from bundle/lib/ on hosts without system copies.
python3 - "$BUNDLE_DIR/lib" <<'PY'
import glob
import os
import struct
import sys

lib_dir = sys.argv[1]
patterns = (
    os.path.join(lib_dir, "libayatana-*.so*"),
    os.path.join(lib_dir, "libdbusmenu-*.so*"),
)
missing = []
for pat in patterns:
    for path in sorted(glob.glob(pat)):
        if os.path.islink(path) or not os.path.isfile(path):
            continue
        with open(path, "rb") as f:
            data = f.read()
        if len(data) < 64 or data[:4] != b"\x7fELF" or data[4] != 2:
            continue
        e_shoff = struct.unpack_from("<Q", data, 40)[0]
        e_shentsize, e_shnum = struct.unpack_from("<HH", data, 58)
        sections = [
            struct.unpack_from("<IIQQQQIIQQ", data, e_shoff + i * e_shentsize)
            for i in range(e_shnum)
        ]
        paths = []
        for s in sections:
            sh_type, sh_offset, sh_size, sh_link = s[1], s[4], s[5], s[6]
            if sh_type != 6:  # SHT_DYNAMIC
                continue
            str_off = sections[sh_link][4]
            for pos in range(sh_offset, sh_offset + sh_size, 16):
                d_tag, d_val = struct.unpack_from("<qQ", data, pos)
                if d_tag == 0:
                    break
                if d_tag in (15, 29):  # DT_RPATH, DT_RUNPATH
                    end = data.index(b"\x00", str_off + d_val)
                    paths.extend(data[str_off + d_val:end].decode().split(":"))
        if "$ORIGIN" not in paths:
            missing.append(os.path.basename(path))

if missing:
    sys.exit(
        "bundled tray libraries missing $ORIGIN RUNPATH (install patchelf during CMake build): "
        + ", ".join(missing)
    )
PY

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

DESKTOP_SRC="$REPO_ROOT/linux/packaging/${APP_ID}.desktop"
METAINFO_SRC="$REPO_ROOT/linux/packaging/${APP_ID}.metainfo.xml"
ICON_SRC="$REPO_ROOT/assets/app_icon.png"
LICENSE_SRC="$REPO_ROOT/LICENSE"
STAGED_METAINFO="$WORK_DIR/${APP_ID}.metainfo.xml"

# Ensure the AppStream metainfo shipped in the packages lists this release
# in descending version order.
python3 - "$METAINFO_SRC" "$STAGED_METAINFO" "$VERSION" "$RELEASE_DATE" <<'PY'
import sys
import xml.etree.ElementTree as ET

src, dst, version, rel_date = sys.argv[1:5]
tree = ET.parse(src)
root = tree.getroot()
releases = root.find("releases")
if releases is None:
    releases = ET.SubElement(root, "releases")

existing = {el.get("version") for el in releases.findall("release")}
if version not in existing:
    rel = ET.Element("release", {"version": version, "date": rel_date, "type": "stable"})
    url = ET.SubElement(rel, "url", {"type": "details"})
    url.text = f"https://github.com/lollipopkit/flutter_server_box/releases/tag/v{version}"
    releases.append(rel)

def ver_key(el: ET.Element) -> tuple[int, ...]:
    raw = (el.get("version") or "0").lstrip("v")
    return tuple(int(p) if p.isdigit() else 0 for p in raw.split("."))

sorted_rels = sorted(releases.findall("release"), key=ver_key, reverse=True)
for el in list(releases):
    releases.remove(el)
for el in sorted_rels:
    releases.append(el)

ET.indent(tree, space="  ")
tree.write(dst, encoding="utf-8", xml_declaration=True)
with open(dst, "ab") as f:
    f.write(b"\n")
PY

if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$DESKTOP_SRC"
fi

if command -v appstreamcli >/dev/null 2>&1; then
  appstreamcli validate --pedantic --no-net "$STAGED_METAINFO"
fi

# Build the portable tarball with a single top-level directory so manual
# extraction is clean and Flatpak's default `strip-components: 1` exposes
# `bundle/` and `share/` directly.
TAR_ROOT_NAME="${APP_NAME}_v${VERSION}_linux_amd64"
TAR_STAGE="$WORK_DIR/$TAR_ROOT_NAME"
mkdir -p \
  "$TAR_STAGE/bundle" \
  "$TAR_STAGE/share/applications" \
  "$TAR_STAGE/share/metainfo" \
  "$TAR_STAGE/share/icons/hicolor/512x512/apps" \
  "$TAR_STAGE/share/licenses/${APP_ID}"

cp -a "$BUNDLE_DIR/." "$TAR_STAGE/bundle/"
install -m 644 "$DESKTOP_SRC" "$TAR_STAGE/share/applications/${APP_ID}.desktop"
install -m 644 "$STAGED_METAINFO" "$TAR_STAGE/share/metainfo/${APP_ID}.metainfo.xml"
install -m 644 "$ICON_SRC" "$TAR_STAGE/share/icons/hicolor/512x512/apps/${APP_ID}.png"
install -m 644 "$LICENSE_SRC" "$TAR_STAGE/share/licenses/${APP_ID}/LICENSE"

TAR_PATH="$OUT_DIR/${TAR_ROOT_NAME}.tar.gz"
COPYFILE_DISABLE=1 tar -C "$WORK_DIR" -czf "$TAR_PATH" "$TAR_ROOT_NAME"

# Sanity-check tarball contents.
tar_listing="$(tar -tzf "$TAR_PATH")"
for entry in \
  "${TAR_ROOT_NAME}/bundle/${APP_NAME}" \
  "${TAR_ROOT_NAME}/share/applications/${APP_ID}.desktop" \
  "${TAR_ROOT_NAME}/share/metainfo/${APP_ID}.metainfo.xml" \
  "${TAR_ROOT_NAME}/share/icons/hicolor/512x512/apps/${APP_ID}.png" \
  "${TAR_ROOT_NAME}/share/licenses/${APP_ID}/LICENSE"; do
  grep -Fxq "$entry" <<< "$tar_listing" || {
    echo "::error::tarball missing expected entry: $entry" >&2
    exit 1
  }
done

if [[ "$SKIP_NFPM" == true ]]; then
  echo "created: $TAR_PATH"
  exit 0
fi

command -v nfpm >/dev/null 2>&1 || {
  echo "::error::nfpm not found in PATH" >&2
  exit 1
}

DEB_PATH="$OUT_DIR/${APP_NAME}_v${VERSION}_amd64.deb"
RPM_PATH="$OUT_DIR/${APP_NAME}_v${VERSION}_x86_64.rpm"
RENDERED_NFPM="$WORK_DIR/nfpm.yaml"

python3 - "$REPO_ROOT/linux/packaging/nfpm.yaml" "$RENDERED_NFPM" "$VERSION" "$BUNDLE_DIR" "$STAGED_METAINFO" "$APP_NAME" <<'PY'
import json
import re
import sys

src, dst, version, bundle_dir, metainfo, app_name = sys.argv[1:7]
with open(src, encoding="utf-8") as f:
    content = f.read()

replacements = {
    '"${VERSION}"': json.dumps(version),
    '"${BUNDLE_DIR}/"': json.dumps(f"{bundle_dir}/"),
    '"/opt/serverbox/${APP_NAME}"': json.dumps(f"/opt/serverbox/{app_name}"),
    '"${METAINFO_FILE}"': json.dumps(metainfo),
}
pattern = re.compile("|".join(re.escape(k) for k in replacements))
rendered = pattern.sub(lambda m: replacements[m.group(0)], content)
if "${" in rendered:
    sys.exit(f"unrendered placeholder left in {dst}")
with open(dst, "w", encoding="utf-8") as f:
    f.write(rendered)
PY

(
  cd "$REPO_ROOT"
  nfpm package --config "$RENDERED_NFPM" --packager deb --target "$DEB_PATH"
  nfpm package --config "$RENDERED_NFPM" --packager rpm --target "$RPM_PATH"
)

# Verify .deb metadata and payload when dpkg-deb is available.
if command -v dpkg-deb >/dev/null 2>&1; then
  dpkg-deb --info "$DEB_PATH"
  deb_contents="$(dpkg-deb --contents "$DEB_PATH")"
  for path in \
    "./opt/serverbox/${APP_NAME}" \
    "./usr/bin/serverbox" \
    "./usr/share/applications/${APP_ID}.desktop" \
    "./usr/share/metainfo/${APP_ID}.metainfo.xml" \
    "./usr/share/icons/hicolor/512x512/apps/${APP_ID}.png" \
    "./usr/share/licenses/serverbox/LICENSE"; do
    grep -Fq "$path" <<< "$deb_contents" || {
      echo "::error::.deb missing expected path: $path" >&2
      exit 1
    }
  done
fi

# Verify .rpm magic header (0xed 0xab 0xee 0xdb) and inspect if `rpm` is present.
python3 - "$RPM_PATH" <<'PY'
import sys
with open(sys.argv[1], "rb") as f:
    magic = f.read(4)
if magic != b"\xed\xab\xee\xdb":
    sys.exit(f"invalid RPM magic in {sys.argv[1]}: {magic!r}")
PY
if command -v rpm >/dev/null 2>&1; then
  rpm -qip "$RPM_PATH" >/dev/null
  rpm_contents="$(rpm -qlp "$RPM_PATH")"
  for path in \
    "/opt/serverbox/${APP_NAME}" \
    "/usr/bin/serverbox" \
    "/usr/share/applications/${APP_ID}.desktop" \
    "/usr/share/metainfo/${APP_ID}.metainfo.xml" \
    "/usr/share/icons/hicolor/512x512/apps/${APP_ID}.png" \
    "/usr/share/licenses/serverbox/LICENSE"; do
    grep -Fxq "$path" <<< "$rpm_contents" || {
      echo "::error::.rpm missing expected path: $path" >&2
      exit 1
    }
  done
fi

echo "created:"
ls -lh "$DEB_PATH" "$RPM_PATH" "$TAR_PATH"
