#!/usr/bin/env bash
# Refresh the vendored copy of Yet Another Bench Script.
#
# The script is shipped as an asset rather than fetched by the server at run
# time, so updating it is a commit here. This fetches one pinned revision,
# writes it to assets/, and prints the three constants that have to move with
# it — `test/yabs_script_test.dart` fails until they agree with the file.
#
# Usage:
#   scripts/update-yabs.sh              # latest revision touching yabs.sh
#   scripts/update-yabs.sh <commit-sha> # a specific one
#
# Upstream: https://github.com/masonr/yet-another-bench-script (WTFPL)
set -euo pipefail

repo="masonr/yet-another-bench-script"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$root/assets/yabs.sh"

commit="${1:-}"
if [ -z "$commit" ]; then
  # `gh` rather than the anonymous API: the unauthenticated rate limit is
  # shared per address and is routinely already spent.
  commit="$(gh api "repos/$repo/commits?path=yabs.sh&per_page=1" --jq '.[0].sha')"
fi

echo "Fetching $repo@$commit"
curl -fsSL "https://raw.githubusercontent.com/$repo/$commit/yabs.sh" -o "$dest"

version="$(sed -n 's/^YABS_VERSION="\(.*\)"$/\1/p' "$dest" | head -1)"
if [ -z "$version" ]; then
  echo "No YABS_VERSION in the downloaded file; refusing to write a copy we cannot identify." >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  digest="$(sha256sum "$dest" | cut -d' ' -f1)"
else
  digest="$(shasum -a 256 "$dest" | cut -d' ' -f1)"
fi

cat <<EOF

Wrote $dest

Update lib/data/model/server/benchmark/yabs_script.dart:

  static const upstreamCommit = '$commit';
  static const upstreamVersion = '$version';
  static const sha256Hex = '$digest';

Then run: flutter test test/yabs_script_test.dart
EOF
