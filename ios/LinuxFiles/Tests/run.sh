#!/bin/sh
# `GuestPath` and `DirHandle` on the host: neither needs iOS.
set -eu
dir=$(cd "$(dirname "$0")/.." && pwd)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
swiftc -O "$dir/Tests/main.swift" "$dir/GuestPath.swift" "$dir/DirHandle.swift" -o "$out/linuxfiles-tests"
TMPDIR="$out" "$out/linuxfiles-tests"
