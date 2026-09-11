#!/usr/bin/env bash
# Regenerates assets/model_context.json from models.dev.
#
# The table is how the app knows when a conversation is approaching a model's
# context limit. It ships with the app and goes stale between releases, which
# is why an unknown model falls back to a conservative default rather than to
# nothing — see `ModelContextTable`.
#
# models.dev serves one 4.5 MB document for every provider it knows. What ends
# up here is model id to context window and nothing else: ServerBox only knows
# the model name the user typed, never which provider it came from.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/assets/model_context.json"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Fetching https://models.dev/api.json ..."
curl -fsSL --max-time 120 "https://models.dev/api.json" -o "$tmp/api.json"
etag="$(curl -fsSI --max-time 30 "https://models.dev/api.json" | awk 'tolower($1) == "etag:" { print $2 }' | tr -d '\r"')"

python3 - "$tmp/api.json" "$out" "$etag" <<'PY'
import json, sys, datetime

source, out, etag = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.load(open(source))

# One id can appear under several providers with different limits — an
# aggregator may serve a shorter window than the model's own. Keep the
# smallest: compacting early costs a summary, compacting late costs the turn.
by_id = {}
for provider in data.values():
    for model_id, model in (provider.get('models') or {}).items():
        context = (model.get('limit') or {}).get('context')
        if not context:
            continue
        key = model_id.lower()
        by_id[key] = min(by_id.get(key, context), context)

document = {
    'source': 'https://models.dev/api.json',
    'etag': etag,
    'generated': datetime.date.today().isoformat(),
    'models': dict(sorted(by_id.items())),
}
with open(out, 'w') as handle:
    json.dump(document, handle, separators=(',', ':'), sort_keys=False)
    handle.write('\n')

print(f'{len(by_id)} models -> {out}')
PY

echo "Remember: test/model_context_test.dart asserts the shape, not the values."
