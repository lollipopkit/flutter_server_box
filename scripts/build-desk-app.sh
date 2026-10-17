#!/bin/sh
# A first-party desk app's package (`monitor/apps/<name>`): its backend
# built for wasm32-wasip2, its UI built against the panel's design system,
# both put with its manifest and the licence into a `.fsba`, file order,
# times and owners fixed so the same sources make the same package.
#
#   scripts/build-desk-app.sh <name>    # → monitor/apps/<name>/target/<publisher>.<name>.fsba
set -eu

name=${1:?usage: scripts/build-desk-app.sh <name>}
root=$(cd "$(dirname "$0")/.." && pwd)
app="$root/monitor/apps/$name"
[ -f "$app/manifest.json" ] || { echo "no app at $app" >&2; exit 1; }

cargo build --quiet --release --target wasm32-wasip2 --manifest-path "$app/Cargo.toml"
(cd "$root/monitor/frontend" && SBM_APP="$name" npx vite build -c vite.app.config.ts)

wasm=$(ls "$app"/target/wasm32-wasip2/release/*.wasm | head -n 1)
python3 -I - "$app" "$wasm" "$root/LICENSE" <<'PY'
import gzip, io, json, os, sys, tarfile

app, wasm, licence = sys.argv[1:4]
manifest = json.load(open(os.path.join(app, 'manifest.json')))
out = os.path.join(app, 'target', f"{manifest['publisher']}.{manifest['name']}.fsba")
files = {'manifest.json': open(os.path.join(app, 'manifest.json'), 'rb').read(), 'backend.wasm': open(wasm, 'rb').read(), 'LICENSE': open(licence, 'rb').read()}
ui = os.path.join(app, 'target', 'ui')
for base, _, names in os.walk(ui):
    for n in names:
        path = os.path.join(base, n)
        files['ui/' + os.path.relpath(path, ui).replace(os.sep, '/')] = open(path, 'rb').read()
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
