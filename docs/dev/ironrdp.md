# IronRDP

`third_party/ironrdp` is upstream IronRDP's **main**, not a release, plus a few ServerBox commits (branch `serverbox`). `sbm_ffi` takes every IronRDP crate from it by path, on ring (`rustls-ring`). Certificate pinning is `sbm_ffi`'s, on upstream's validation callback; accepted advisories are in `.cargo/audit.toml`.

`serverbox` is squash-merged, so ServerBox's own commits live on the latest `patches/upstream-<sha>` tag.

## Following upstream

1. Branch from upstream's main.
2. `git cherry-pick $(git rev-list --reverse --first-parent --no-merges <old upstream sha>..<tag>)`.
3. `git merge -s ours origin/serverbox`, so the squash merges cleanly without a force push.
4. Tag the new patches again (`patches/upstream-<sha>`).
