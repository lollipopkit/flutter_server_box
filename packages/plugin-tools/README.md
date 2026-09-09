# @serverbox/plugin-tools

Packing a ServerBox plugin, and writing the repository a client reads.

Three commands, one archive format, and no dependencies beyond Bun.

## Packing

```sh
cd packages/plugins/disk-usage
bun run pack        # bun run build && bun run ../../plugin-tools/bin/pack.ts .
```

Writes `dist/<id>-<version>.sbp`: a zip holding `manifest.json`, `plugin.js`,
`l10n/<locale>.json` and `icon.png`. Those four are what `PluginPackage.read`
looks for; everything else in the directory stays where it is.

It refuses to write a package the app would refuse to install — a manifest with
no `id`, `version` or `abi`, a locale the manifest declares with no file behind
it, translations with no `en` to fall back to, more bytes than the app unpacks.
A packer that succeeded there would move the failure to whoever downloads it,
where there is nothing to be done about it.

There was a copy of this in each plugin's `scripts/`, all three identical. The
translations were missing from all of them for a while, which is the failure
that argues for one copy: a plugin installed from its directory with its
translations and silently fell back to English once it was packaged.

## The repository

```sh
bun run packages/plugin-tools/bin/repo.ts --repo ../serverbox-plugins
```

With no paths it takes every `packages/plugins/*/dist/*.sbp` in the checkout and
writes, into the repository:

```
repo.toml                              schema, name
plugins/app/serverbox/diskusage.toml   one file per plugin, naming a url
```

**Nothing binary goes in.** A version names the address its package is served
from, and for the official repository that is **its own releases, one per plugin
version**: the tag is `<id>-<version>` (`tagOf`), the same string the packer
names the file after, so a release and its one asset read the same. A version's
URL is `--base-url` + that tag + the file name.

One release per version rather than one release with everything, because a tag
then identifies exactly one set of bytes — "which release is this package in"
keeps an answer, and a version can be withdrawn by deleting a release without
touching another.

| Option | |
|---|---|
| `--repo` | The repository directory to write into, and to merge with. |
| `--base-url` | Where releases are downloaded from; a version's `url` is this, its tag, then the file name. |
| `--name` | What it calls itself, written to `repo.toml` when creating one. |
| `--allow-republish` | Accept a version whose bytes changed. |

A file `<package>.notes` beside a `.sbp` becomes that release's `notes`. Nothing
writes it — "what changed" is not derivable from a package — and a file that
carried notes once keeps them.

### Shaped after a Homebrew tap

A tap is a git repository with one file per formula, each naming where the thing
itself lives; a client fetches the tree and reads what is in it. So there is no
single document that every publish rewrites, a pull request touches exactly the
plugin it is about, and **the repository stays text**.

**The path is the id.** An id is reverse-DNS, so its first two parts are the
publisher and the rest is the plugin: `app.serverbox.diskusage` lives at
`plugins/app/serverbox/diskusage.toml`. That shards a growing directory the way
`Formula/a/…` does while keeping one publisher's plugins together, which a
first-letter shard would not. A file whose path and `id` disagree is refused
rather than read — that is what a copy into the wrong folder looks like, and
reading it would offer something the repository does not think it is serving.

### Three rules in it are decisions

**The digest is computed from the bytes being published.** The file and the
package come from different places, so it is what binds an address to a
particular set of bytes — the same thing a Homebrew formula's `sha256` does. A
hand-copied one will eventually be wrong, and the way that shows up is nobody
being able to install.

**A plugin's file is merged into, never replaced.** It lists every version still
on offer, because one repository serves apps of different ages and each installs
the newest release its own ABI can run. Writing only what is in `dist/` today
would drop the rest, and an app that needed one would see the plugin vanish
rather than see a version it can use. Only the plugins a run touched are
rewritten, so a repository full of other people's files does not churn.

**Republishing a version with different bytes is refused.** Nothing breaks the
instant it happens, because the app verifies at install time against the file.
What breaks is a version number identifying a particular set of bytes, which is
what the rest of this relies on. `--allow-republish` says it was meant.

## Reading back what was served

```sh
bun run packages/plugin-tools/bin/verify.ts ../serverbox-plugins
bun run packages/plugin-tools/bin/verify.ts https://github.com/lollipopkit/serverbox-plugins
```

Takes a directory or an address. **The address form is the one that matters**: it
fetches what a client fetches — a tarball of the latest tree — then downloads
every version it lists and checks it against the digest and size its file gave
it, plus the manifest *inside* each package against the file that names it. So
it catches the case the two-place split makes possible: a file published without
the package it names.

Everything else here works from the bytes on the machine that built them, and the
ways publishing goes wrong live in the gap between those and the ones an app
downloads: a package that was never uploaded, a file naming an address that
answers 404, a tree edited by hand.

GitHub resolves `HEAD` through a cache that lagged a push by about ten seconds
when this was written, so a verify that misses immediately after publishing is
worth re-running rather than believed.

## Publishing to the official repository

`scripts/publish-plugins.sh` in this repository does the whole thing: pack,
create a release per new version, write the tree, check it locally, commit, push,
and fetch it back the way a client does. **The releases go up before the files
that name them** — a file pointing at a 404 is broken for everybody who reads it,
while a release nothing lists yet is invisible and harmless. An existing release
is left alone rather than re-uploaded: its tag already names that version.

## Tests

```sh
bun test
```

`test/fixtures/plugin_repo/` in the app is this tool's actual output, and
`test/plugin_repo_generated_test.dart` reads it with the app's own reader. The
two sides are in different languages and a key spelled differently is not a
compile error on either — it is a repository that looks empty to everybody. The
address table in `test/fetch.test.ts` is the same table as the one in the app's
`test/plugin_repo_test.dart`, for the same reason.
