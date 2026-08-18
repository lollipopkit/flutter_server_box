# Contributing to ServerBox

Any positive contribution is welcome — code, translations, bug reports, and
documentation alike.

## Before you open a pull request

- **Small fixes:** just open the pull request.
- **New features or anything that changes how the app behaves:** open an issue
  first and describe the idea. It avoids the case where the work is finished and
  the direction turns out to be wrong.
- **Subjective changes** (for example "this other UI looks better") may not be
  accepted. Anything with a concrete argument behind it is welcome to be
  discussed.

## Contributor License Agreement

Every contributor signs the [CLA](CLA.md) once
([中文译本](CLA_zh.md)). An automated check posts the instructions on your first
pull request, and you sign by leaving one comment:

```
I have read the CLA Document and I hereby sign the CLA
```

**The short version:** ServerBox is AGPLv3 and is also distributed through the
App Store, whose terms cannot all be satisfied alongside every AGPLv3
condition. The agreement grants the maintainer the right to ship your work in
those builds. You keep the copyright to what you wrote, and you can reuse it
anywhere else however you like. Read [CLA.md](CLA.md) for the terms that
actually bind — the paragraph above is a summary and nothing more.

Two things that trip the check up:

- **Commits authored by an email address not attached to your GitHub account.**
  The check then cannot tell who wrote them. Add the address at
  <https://github.com/settings/emails> (it can stay private) and comment
  `recheck`.
- **Co-authored commits.** Everyone who authored a commit in the pull request
  signs, not only whoever opened it.

## Development

### Setup

1. Install [Flutter](https://flutter.dev/docs/get-started/install), and a
   [Rust](https://rustup.rs) toolchain — part of the status parsing is a Rust
   crate reached through FFI.
2. `make deps` — fetch Dart/Flutter dependencies.
3. `make run` — start the app. `make help` lists everything else.

Working on the server-side monitor needs Node as well: `make monitor-dev` runs
its backend (API on `:3770`) and its Svelte panel (vite on `:3000`) together.
`monitor/CLAUDE.md` covers that side of the repository.

### Code generation

Models use freezed, json_serializable, hive_ce, and riverpod annotations.
After changing any of them:

```sh
make gen          # build_runner + gen-l10n
```

Never edit `*.g.dart` or `*.freezed.dart` by hand; regenerate instead.

After changing `crates/sbm_ffi/src/api`, regenerate the FFI bindings with
`flutter_rust_bridge_codegen generate`. `lib/src/rust/` is generated too.

### Formatting

**Do not run formatters.** The codebase has formatting that is deliberate, and a
reformat buries the actual change in noise. Match the style of the file you are
editing.

### Checks before you push

```sh
make analyze              # flutter analyze lib test
make test                 # flutter test
cargo test --workspace    # parser, native sampler, FFI, monitor

# Only if you touched the monitor panel
cd monitor/frontend && npm run test && npm run check
```

`flutter analyze` runs on every pull request; the Rust tests are worth running
locally if you touched anything under `crates/` or `monitor/`.

### Commit messages

One prefix, lowercase, then a short description in the imperative:

```
feat: add temperature unit setting
fix: reconnect after the tunnel drops
docs: describe the CLA check
opt.: cache the parsed disk list
rm: drop the unused sensor fallback
migrate: move network parsing to Rust
```

Common prefixes: `feat:`, `fix:`, `docs:`, `opt.:`, `rm:`, `migrate:`,
`refactor:`, `test:`, `chore:`. Write commit messages and code comments in
English.

## Translations

New strings go into `lib/l10n/app_en.arb`, then `make gen` regenerates the Dart
side. Translate by editing `lib/l10n/app_<locale>.arb`.

- A [guide](https://blog.lpkt.cn/posts/faq/) is on the maintainer's blog.
- Partial translations are fine — send what you have.
- Machine-translated locales exist (marked in the README) and improvements to
  them from native speakers are especially welcome.

## Attribution

Contributors are credited in the README. If a name is missing, comment on the
issue or pull request and it will be added.
