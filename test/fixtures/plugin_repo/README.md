# A generated plugin repository

What `packages/plugin-tools` actually emitted, kept so the app's reader is tested
against the tool's output rather than against prose. The same reason
`rootfs_manifest/ci_produced.json` is here: the two sides are in different
languages, and nothing else makes them meet.

Refresh it after changing either side:

```sh
for p in packages/plugins/*/; do (cd "$p" && bun run pack); done
rm -rf /tmp/fixture-repo && mkdir -p /tmp/fixture-repo
bun run packages/plugin-tools/bin/repo.ts --repo /tmp/fixture-repo --name "ServerBox plugins"
rm -rf test/fixtures/plugin_repo/plugins
cp /tmp/fixture-repo/repo.toml test/fixtures/plugin_repo/
cp -R /tmp/fixture-repo/plugins test/fixtures/plugin_repo/
```

Generated into a temporary directory rather than copied out of the published
repository, so refreshing it needs nothing but this checkout.

**The `.sbp` packages are deliberately not here.** A real repository carries
them, and each `path` above names one — but they are build output of the bundler,
they change on every rebuild, and this fixture is about the *files*: that the
tool writes what the app reads, at the paths the app looks in.
`plugin_repo_generated_test.dart` therefore asserts the shape and checks the ids,
versions and ABIs against each plugin's own `manifest.json`, which is what makes
a stale fixture fail rather than pass quietly. Whether a package matches its
digest is `bin/verify.ts`'s question, and it asks it of a real repository.
