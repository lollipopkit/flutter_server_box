#!/usr/bin/env bash
# Builds the --dart-define-from-file input for integration_test/ios_bench_test.dart.
#
# The benchmark script and the prebuilt aarch64 binary belong to the ish-arm64
# fork, under build/ish/ish-arm64/benchmark/assets/ — where
# scripts/build-ish-ios.sh leaves them. They are passed in rather than copied:
# they are the thing being measured, and a second copy here would be a second
# thing to keep in step. It also keeps them out of the shipped app, since a
# define reaches only the build that asks for it.
#
#     scripts/ios-bench-defines.sh > /tmp/bench.json
#
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets="$root/build/ish/ish-arm64/benchmark/assets"

if [ ! -f "$assets/shellbench.sh" ]; then
    echo "no $assets/shellbench.sh — run scripts/build-ish-ios.sh first" >&2
    exit 1
fi

# The C half is optional: without it the suite still reports every shell
# section, and reporting nothing because one binary is missing would be worse.
python3 - "$assets" <<'PY'
import base64, json, pathlib, sys

assets = pathlib.Path(sys.argv[1])

# Both values are base64. A define reaches the frontend server as a literal
# `-DNAME=value` argument, so a value with newlines in it is read as another
# source file to compile — and this script's `#!` line then parses as a URI
# fragment. One line of ASCII is the only shape that survives.
shellbench = (assets / "shellbench.sh").read_text()

# The script picks its clock by asking whether `date` understands %N, and reads
# the answer as either "%N" or "N" left unexpanded. Busybox — which is what the
# guest has — prints an empty string instead, so both tests pass and the script
# settles on `date +%s%N`, which there yields whole seconds. Divided down to
# milliseconds that is a constant, and every measurement comes out zero: 31
# rows, all present, none of them a number. /proc/uptime does advance in the
# guest (centiseconds), so the fallback this reaches is a working clock.
#
# Anchored on the exact line so that an upstream edit stops the run rather than
# silently restoring the zeros.
ANCHOR = '''if date +%s%N >/tmp/_null 2>&1 && [ "$(date +%N)" != "%N" ] && [ "$(date +%N)" != "N" ]; then'''
PATCHED = '''if date +%s%N >/tmp/_null 2>&1 && [ -n "$(date +%N)" ] && [ "$(date +%N)" != "%N" ] && [ "$(date +%N)" != "N" ]; then'''

if ANCHOR not in shellbench:
    sys.exit("shellbench.sh no longer has the clock-selection line this patches")
shellbench = shellbench.replace(ANCHOR, PATCHED, 1)

out = {"SHELLBENCH_B64": base64.b64encode(shellbench.encode()).decode()}

cbench = assets / "cbench_lite_arm64"
if cbench.exists():
    out["CBENCH_ARM64_B64"] = base64.b64encode(cbench.read_bytes()).decode()

print(json.dumps(out))
PY
