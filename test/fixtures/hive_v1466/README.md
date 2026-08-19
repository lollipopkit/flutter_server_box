# Hive boxes as v1.0.1466 wrote them

Input for `test/hive_v1466_migration_test.dart`. Every file here was produced
by **that release's own generated adapters**, not by the current tree — which
is the whole point. A test that seeds its boxes through today's adapters can
only prove today's code is self-consistent; it cannot catch a decoder that
disagrees with what the old release actually put on disk.

v1.0.1466 is the build the App Store served while the SQLite migration was
written, so it is the version most installs upgrade from.

## What is in it

| File | Contents |
| --- | --- |
| `server_enc.hive` | 5 servers: password auth, key auth with every optional field set, jump hosts, `ProxyCommand`, and one with nothing optional |
| `key_enc.hive` | 2 private keys (OpenSSH and RSA, fake bodies) |
| `snippet_enc.hive` | 3 snippets, one with CJK, emoji, quotes, backslashes and a newline |
| `setting_enc.hive` | 14 keys covering `int`, `double`, `bool`, `String`, `List<String>`, `List<int>`, `Map` and an enum stored by name |
| `history_enc.hive` | SFTP paths, SSH tabs |
| `docker_enc.hive` | Docker and Podman hosts, global and per-server |
| `port_forward_enc.hive` | A local and a remote forward |
| `connection_stats_enc.hive` | 120 rows across 2 servers, every `ConnectionResult` kind |
| `conn_stats_index.hive` | The one box 1466 wrote **without a cipher**, kept so the test can prove the import deletes it |

The data is invented. No key, password or host here belongs to anyone.

The boxes are encrypted with the key the test derives from `Random(1)`, so
they open there and nowhere else.

## Regenerating, or adding a fixture for another release

`gen_fixture.dart.txt` is the generator. It is `.txt` rather than `.dart`
because it is written against v1.0.1466's APIs and would fail `flutter analyze`
in this tree.

```sh
git worktree add /tmp/sb1466 v1.0.1466
cd /tmp/sb1466
git submodule update --init packages/dartssh2 packages/circle_chart \
  packages/xterm packages/watch_connectivity packages/plain_notification_token \
  packages/fl_lib packages/fl_build
flutter pub get
cp <repo>/test/fixtures/hive_v1466/gen_fixture.dart.txt test/gen_fixture.dart
flutter test test/gen_fixture.dart
cp /tmp/sb1466-out/*.hive <repo>/test/fixtures/hive_v1466/
cd <repo> && git worktree remove /tmp/sb1466
```

Two things bite when pointing this at a different tag:

- **The box directory.** At 1466 `HiveStore.init` asks path_provider for the
  documents directory on every platform but Linux and Windows, so the
  generator mocks that channel. A different tag may resolve it differently.
- **The encryption key.** The generator and the reading test must derive the
  same one. Both build it from `Random(1)`; keep that in step or the boxes
  will not open.

Do not regenerate these files to make a failing test pass. They are a record
of what a shipped release wrote, and editing them to suit the current decoder
removes the only evidence the decoder is wrong.
