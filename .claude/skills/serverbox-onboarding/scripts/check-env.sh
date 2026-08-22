#!/bin/sh
# Read-only check of a ServerBox development environment.
#
# Reports what is installed against what the repository asks for. It installs
# nothing, writes nothing and never touches the network, so it is safe to run
# before diagnosing a build failure by hand — most first-run failures are one
# of the things below, and the symptom rarely names the cause.
#
# Usage: sh .claude/skills/serverbox-onboarding/scripts/check-env.sh [repo-root]
# Exit:  0 = nothing blocking, 1 = at least one FAIL

set -u

ROOT="${1:-}"
if [ -z "$ROOT" ]; then
    ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=$(pwd)
fi

if [ ! -f "$ROOT/pubspec.yaml" ] || [ ! -d "$ROOT/crates/sbm_ffi" ]; then
    echo "Not a flutter_server_box checkout: $ROOT"
    echo "Pass the repository root as the first argument."
    exit 1
fi

FAILED=0

if [ -t 1 ]; then
    C_OK=$(printf '\033[32m'); C_WARN=$(printf '\033[33m')
    C_BAD=$(printf '\033[31m'); C_OFF=$(printf '\033[0m')
else
    C_OK=''; C_WARN=''; C_BAD=''; C_OFF=''
fi

ok()   { printf '%s  ok  %s %s\n' "$C_OK" "$C_OFF" "$1"; }
warn() { printf '%s warn %s %s\n' "$C_WARN" "$C_OFF" "$1"; }
bad()  { printf '%s FAIL %s %s\n' "$C_BAD" "$C_OFF" "$1"; FAILED=1; }

# Dotted-version comparison, missing components counting as 0, and a
# prerelease ranking below the release it precedes.
#
# The last part is the whole reason this is not three lines. `pub` reads these
# constraints as semver, where 3.44.9-0.1.pre is *older* than 3.44.9 — so a
# beta-channel Flutter fails `pub get` against `flutter: ">=3.44.9"`. Comparing
# only the numeric part reports that install as ok and leaves the actual
# failure to be met later, with a message about version solving rather than
# about the channel.
ver_ge() {
    [ "$(awk -v a="$1" -v b="$2" 'BEGIN {
        # Split the prerelease suffix off each side; what is left is numeric.
        ia = index(a, "-"); pa = (ia > 0) ? substr(a, ia + 1) : ""
        ib = index(b, "-"); pb = (ib > 0) ? substr(b, ib + 1) : ""
        if (ia > 0) a = substr(a, 1, ia - 1)
        if (ib > 0) b = substr(b, 1, ib - 1)

        na = split(a, x, "."); nb = split(b, y, ".")
        n = (na > nb) ? na : nb
        for (i = 1; i <= n; i++) {
            va = (i <= na) ? x[i] + 0 : 0
            vb = (i <= nb) ? y[i] + 0 : 0
            if (va > vb) { print 1; exit }
            if (va < vb) { print 0; exit }
        }
        # Numerically equal. A prerelease loses to a release; two prereleases
        # are not ranked against each other, which no check here needs.
        if (pa != "" && pb == "") { print 0; exit }
        print 1
    }')" = "1" ]
}

echo "ServerBox environment check"
echo "  root: $ROOT"
echo

# --- Flutter and Dart -------------------------------------------------------
# Both minimums come from `environment:` in pubspec.yaml, which is what pub
# enforces; anything older fails at resolution rather than at build time.
want_flutter=$(sed -n 's/^ *flutter: *">= *\([0-9.]*\)".*/\1/p' "$ROOT/pubspec.yaml" | head -1)
want_dart=$(sed -n 's/^ *sdk: *">= *\([0-9.]*\)".*/\1/p' "$ROOT/pubspec.yaml" | head -1)

if command -v flutter >/dev/null 2>&1; then
    # The prerelease suffix is kept: `ver_ge` needs it, and dropping it here is
    # what made a beta SDK compare equal to the stable release it precedes.
    have_flutter=$(flutter --version 2>/dev/null | sed -n 's/^Flutter \([0-9][0-9.]*\(-[0-9A-Za-z.]*\)\{0,1\}\).*/\1/p' | head -1)
    if [ -z "$have_flutter" ]; then
        warn "flutter found but its version could not be parsed"
    elif [ -n "$want_flutter" ] && ! ver_ge "$have_flutter" "$want_flutter"; then
        bad "flutter $have_flutter is older than the required $want_flutter"
    else
        ok "flutter $have_flutter (needs >= ${want_flutter:-?})"
    fi
else
    bad "flutter not on PATH"
fi

if command -v dart >/dev/null 2>&1; then
    have_dart=$(dart --version 2>&1 | sed -n 's/.*version: *\([0-9][0-9.]*\(-[0-9A-Za-z.]*\)\{0,1\}\).*/\1/p' | head -1)
    if [ -n "$want_dart" ] && [ -n "$have_dart" ] && ! ver_ge "$have_dart" "$want_dart"; then
        bad "dart $have_dart is older than the required $want_dart"
    else
        ok "dart ${have_dart:-?} (needs >= ${want_dart:-?})"
    fi
else
    bad "dart not on PATH"
fi

# --- Rust -------------------------------------------------------------------
# crates/sbm_ffi is compiled into every app build by hook/build.dart, so this
# is required even for `flutter run`. The channel is pinned per-crate; rustup
# installs it on first use, which a distro rustc will not do.
want_rust=$(sed -n 's/^ *channel *= *"\([^"]*\)".*/\1/p' "$ROOT/crates/sbm_ffi/rust-toolchain.toml" | head -1)

if command -v cargo >/dev/null 2>&1; then
    have_rust=$(rustc --version 2>/dev/null | awk '{print $2}')
    ok "cargo present, rustc ${have_rust:-?} (crates/sbm_ffi pins ${want_rust:-?})"
    if command -v rustup >/dev/null 2>&1; then
        if [ -n "$want_rust" ] && rustup toolchain list 2>/dev/null | grep -q "^$want_rust"; then
            ok "pinned toolchain $want_rust installed"
        elif [ -n "$want_rust" ]; then
            warn "pinned toolchain $want_rust not installed yet; rustup fetches it on the first build"
        fi
    else
        warn "rustup not on PATH — rust-toolchain.toml's pin will be ignored by a bare rustc"
    fi
else
    bad "cargo not on PATH — the app cannot build without a Rust toolchain"
fi

# --- Node -------------------------------------------------------------------
# Only the monitor panel, the docs site and the website need it. Absent is
# fine for app-only work, hence a warning rather than a failure.
node_pin="$ROOT/monitor/frontend/.node-version"
want_node=$([ -f "$node_pin" ] && head -1 "$node_pin" || echo "")
if command -v node >/dev/null 2>&1; then
    have_node=$(node --version 2>/dev/null | sed 's/^v//')
    if [ -n "$want_node" ] && ! ver_ge "$have_node" "${want_node%%.*}"; then
        warn "node $have_node is older than the pinned $want_node (monitor panel, docs, website)"
    else
        ok "node $have_node (pinned ${want_node:-?})"
    fi
else
    warn "node not on PATH — needed only for the monitor panel, docs site and website"
fi

echo

# --- Submodules -------------------------------------------------------------
# packages/* are path dependencies, so an uninitialised submodule makes
# `flutter pub get` fail on a missing directory without mentioning submodules.
if [ -f "$ROOT/.gitmodules" ]; then
    uninit=$(git -C "$ROOT" submodule status 2>/dev/null | grep -c '^-' || true)
    if [ "${uninit:-0}" -gt 0 ]; then
        bad "$uninit submodule(s) not initialised — run: git submodule update --init --recursive"
        git -C "$ROOT" submodule status 2>/dev/null | grep '^-' | awk '{print "        " $2}'
    else
        ok "submodules initialised"
    fi
fi

# --- Dependencies fetched ---------------------------------------------------
if [ -f "$ROOT/.dart_tool/package_config.json" ]; then
    ok "dart dependencies fetched (.dart_tool/package_config.json present)"
else
    warn "dart dependencies not fetched yet — run: make deps"
fi

if [ -d "$ROOT/monitor/frontend/node_modules" ]; then
    ok "monitor panel dependencies installed"
else
    warn "monitor panel dependencies not installed — 'make monitor-dev' installs them on first run"
fi

# --- flutter_rust_bridge parity ---------------------------------------------
# The Dart and Rust halves are pinned separately. When they disagree,
# RustLib.init throws at startup and the message says nothing about versions.
frb_dart=$(sed -n 's/^  flutter_rust_bridge: *\([^ ]*\).*/\1/p' "$ROOT/pubspec.yaml" | head -1)
frb_rust=$(sed -n 's/^flutter_rust_bridge *= *"=\{0,1\}\([^"]*\)".*/\1/p' "$ROOT/crates/sbm_ffi/Cargo.toml" | head -1)
if [ -n "$frb_dart" ] && [ -n "$frb_rust" ]; then
    if [ "$frb_dart" = "$frb_rust" ]; then
        ok "flutter_rust_bridge $frb_dart matches on both sides"
    else
        bad "flutter_rust_bridge mismatch: pubspec.yaml $frb_dart vs crates/sbm_ffi/Cargo.toml $frb_rust"
    fi
else
    warn "could not read the flutter_rust_bridge version from both sides"
fi

echo
if [ "$FAILED" -eq 0 ]; then
    echo "No blocking problems. Next: make deps, then make run."
else
    echo "Fix the FAIL lines above before building."
fi
exit "$FAILED"
