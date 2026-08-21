#!/usr/bin/env bash
#
# Says whether a built binary carries the ish-arm64 engine, and fails if that
# is not what was asked for.
#
# Usage: scripts/check-ish-linkage.sh <binary> <on|off>
#
#   on   SBM_ISH = 1 — the engine must be linked in
#   off  SBM_ISH = 0 — it must be gone
#
# Why this is a script and not a line in a document
# -------------------------------------------------
# The obvious check is wrong. Every `sbm_ish_*` function is exported whichever
# way the switch is set: Dart looks them up by name, so they carry `used` and
# default visibility, and at SBM_ISH = 0 they are still there as
# two-instruction stubs. Searching a stripped build for `sbm_ish_boot` finds
# it. That was the documented procedure until it was run.
#
# What actually discriminates is the engine's own internals, its strings, and
# the sqlite it drags in — its three libraries are static, so `otool -L` can
# never list them and sqlite is the only linkage it can show.
#
# The `on` case is not symmetry. The first build made with the switch on had no
# engine in it at all: nothing in the app calls those functions, so the linker
# dead-stripped every one of them and the engine with them, and the result was
# a 58 KB binary that failed at runtime rather than at build time. `used` fixed
# it, and this is what stops it coming back.
#
# How many there should be is counted from the header rather than written down.
# It was written down, as 8, and the ninth — `sbm_ish_attach`, which entering
# one of several installed systems needs — turned this check red on a build
# that was correct.

set -euo pipefail

BINARY="${1:-}"
EXPECT="${2:-}"
HEADER="$(cd "$(dirname "$0")/.." && pwd)/ios/Runner/ish/sbm_ish.h"

die() { printf '\033[0;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\033[0;34m==>\033[0m %s\n' "$*"; }

[ -n "$BINARY" ] && [ -n "$EXPECT" ] || die "usage: $0 <binary> <on|off>"
[ -f "$BINARY" ] || die "no such binary: $BINARY"
case "$EXPECT" in on|off) ;; *) die "second argument is 'on' or 'off', got '$EXPECT'" ;; esac

# `|| true` throughout: grep exits 1 on no match, which is a valid answer here
# and must not end the script under `set -e`.
exported="$(nm -gU "$BINARY" 2>/dev/null | grep -c '_sbm_ish_' || true)"
# The declarations, which are the contract Dart resolves against. Counted here
# so that adding one to the header is the whole of adding one.
expected="$(grep -c '^SBM_ISH_EXPORT' "$HEADER" || true)"
[ "$expected" -gt 0 ] || die "no SBM_ISH_EXPORT declarations in $HEADER"
internals="$(nm -a "$BINARY" 2>/dev/null |
  grep -cE 'xX_main_Xx|mount_root|pty_open_fake|generic_openat|do_execve' || true)"
engine_strings="$(LC_ALL=C strings - "$BINARY" 2>/dev/null |
  grep -icE 'ish-arm64|fakefs|realfs|devptsfs' || true)"
sqlite="$(otool -L "$BINARY" 2>/dev/null | grep -c 'libsqlite3' || true)"
bytes="$(stat -f %z "$BINARY" 2>/dev/null || stat -c %s "$BINARY")"

log "$BINARY ($bytes bytes), expecting the engine $EXPECT"
printf '    exported sbm_ish_*   %s\n' "$exported"
printf '    engine internals     %s\n' "$internals"
printf '    engine strings       %s\n' "$engine_strings"
printf '    libsqlite3 in otool  %s\n' "$sqlite"

failed=0
fail() { printf '\033[0;31m  ✗\033[0m %s\n' "$*"; failed=1; }
pass() { printf '\033[0;32m  ✓\033[0m %s\n' "$*"; }

# Both ways round. Dart resolves these by name in the running process, so their
# absence is a runtime failure with no build-time symptom.
if [ "$exported" -eq "$expected" ]; then
  pass "all $expected sbm_ish_* are exported"
else
  # Single quotes around the whole message: the word below is a shell builtin's
  # name and was written in backticks, which inside double quotes is command
  # substitution. Every failure printed "used: command not found" first.
  fail "$exported of $expected sbm_ish_* exported — Dart resolves these by name,
       and the linker dead-strips them without '"'"'used'"'"'"
fi

if [ "$EXPECT" = on ]; then
  [ "$internals" -gt 0 ] && pass "the engine's own symbols are in" \
    || fail "no engine symbol found — the stubs were linked, not the engine"
  [ "$engine_strings" -gt 0 ] && pass "the engine's strings are in" \
    || fail "no engine string found"
  [ "$sqlite" -gt 0 ] && pass "libsqlite3 is linked, as the engine needs" \
    || fail "libsqlite3 is absent — the engine's fakefs cannot work without it"
else
  [ "$internals" -eq 0 ] && pass "no engine symbol" \
    || fail "$internals engine symbols survived the strip"
  [ "$engine_strings" -eq 0 ] && pass "no engine string" \
    || fail "$engine_strings engine strings survived the strip"
  [ "$sqlite" -eq 0 ] && pass "no libsqlite3" \
    || fail "libsqlite3 is still linked"
fi

[ "$failed" -eq 0 ] || die "this binary is not what '$EXPECT' means"
log "as expected"
