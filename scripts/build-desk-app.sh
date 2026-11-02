#!/bin/sh
# A first-party desk app's package (`monitor/apps/<name>`): its backend
# built for wasm32-wasip2, its UI built against the panel's design system,
# both put with its manifest and the licence into a `.fsba`, file order,
# times and owners fixed so the same sources make the same package, and
# signed with the first-party key (`monitor/src/apps/sign.rs`): from the
# keychain item `sbm-app-signing`, or SBM_APP_SIGNING_KEY (base64 PKCS#8
# DER) where there is no keychain; it reaches openssl through a pipe, never
# a file or an argument. SBM_APP_UNSIGNED=1 leaves the package unsigned.
#
#   scripts/build-desk-app.sh <name>          # → monitor/apps/<name>/target/<publisher>.<name>.fsba
#   scripts/build-desk-app.sh <name> --store  # and into store/desk/, which the agent ships and the store offers
set -eu

name=${1:?usage: scripts/build-desk-app.sh <name> [--store]}
root=$(cd "$(dirname "$0")/.." && pwd)
app="$root/monitor/apps/$name"
[ -f "$app/manifest.json" ] || { echo "no app at $app" >&2; exit 1; }

cargo build --quiet --release --target wasm32-wasip2 --manifest-path "$app/Cargo.toml"
(cd "$root/monitor/frontend" && SBM_APP="$name" npx vite build -c vite.app.config.ts)

wasm=$(ls "$app"/target/wasm32-wasip2/release/*.wasm | head -n 1)
python3 -I - "$app" "$wasm" "$root/LICENSE" <<'PY'
import base64, gzip, hashlib, io, json, os, subprocess, sys, tarfile, tempfile

app, wasm, licence = sys.argv[1:4]
manifest = json.load(open(os.path.join(app, 'manifest.json')))
out = os.path.join(app, 'target', f"{manifest['publisher']}.{manifest['name']}.fsba")
files = {'manifest.json': open(os.path.join(app, 'manifest.json'), 'rb').read(), 'backend.wasm': open(wasm, 'rb').read(), 'LICENSE': open(licence, 'rb').read()}
ui = os.path.join(app, 'target', 'ui')
for base, _, names in os.walk(ui):
    for n in names:
        path = os.path.join(base, n)
        files['ui/' + os.path.relpath(path, ui).replace(os.sep, '/')] = open(path, 'rb').read()
if os.environ.get('SBM_APP_UNSIGNED') != '1':
    listing = ''.join(f"{hashlib.sha256(files[p]).hexdigest()}  {p}\n" for p in sorted(files))
    digest = hashlib.sha256(listing.encode()).digest()
    key = os.environ.get('SBM_APP_SIGNING_KEY') or subprocess.run(
        ['security', 'find-generic-password', '-s', 'sbm-app-signing', '-w'], capture_output=True, check=True, text=True).stdout
    r, w = os.pipe()
    os.write(w, base64.b64decode(key.strip()))
    os.close(w)
    del key
    # ed25519 signs in one shot, from a regular file: the digest (public).
    with tempfile.NamedTemporaryFile() as d:
        d.write(digest)
        d.flush()
        sig = subprocess.run(['openssl', 'pkeyutl', '-sign', '-rawin', '-keyform', 'DER', '-inkey', f'/dev/fd/{r}', '-in', d.name],
                             pass_fds=(r,), capture_output=True, check=True).stdout
    os.close(r)
    files['SIGNATURE'] = json.dumps({'key': 'serverbox-2026', 'signature': base64.b64encode(sig).decode()}).encode() + b'\n'
raw = io.BytesIO()
with tarfile.open(fileobj=raw, mode='w', format=tarfile.PAX_FORMAT) as tar:
    for path in sorted(files):
        info = tarfile.TarInfo(path)
        info.size, info.mode, info.mtime = len(files[path]), 0o644, 0
        tar.addfile(info, io.BytesIO(files[path]))
with open(out, 'wb') as f:
    f.write(gzip.compress(raw.getvalue(), mtime=0))
print(out, os.path.getsize(out) >> 10, 'KiB')
PY
if [ "${2:-}" = --store ]; then
  pkg=$(python3 -I -c 'import json, sys; m = json.load(open(sys.argv[1])); print(m["publisher"] + "." + m["name"] + ".fsba")' "$app/manifest.json")
  # A repository's file is at most 8 MiB (fl_theme's MAX_ENTRY_BYTES): a
  # larger one would leave the whole store unreadable to agents.
  [ "$(wc -c < "$app/target/$pkg")" -le 8388608 ] || { echo "$pkg is over 8 MiB, more than the store takes" >&2; exit 1; }
  cp "$app/target/$pkg" "$root/store/desk/$pkg"
  echo "$root/store/desk/$pkg"
fi
