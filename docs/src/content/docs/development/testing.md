---
title: Testing
description: Testing strategies and running tests
---

## Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/disk_test.dart

# Run with coverage
flutter test --coverage
```

## Test Structure

Tests are located in the `test/` directory. The current suite is mostly flat and grouped by parser, model, and utility behavior, for example `disk_test.dart`, `container_test.dart`, and `ssh_config_test.dart`.

## Rust Tests

Status parsing lives in the shared Rust workspace:

```bash
# All Rust tests (parser, native sampler, FFI shell, monitor)
cargo test --workspace

# FFI parity test: asserts the Dart side gets identical results
# through flutter_rust_bridge (build the FFI crate first)
cargo build -p sbm_ffi
flutter test test/frb_parser_test.dart
```

`crates/sbm_parser/tests/dart_compat.rs` locks parser behavior against the
original Dart fixture suite.

### Opt-in tests

Two suites need a real host and are skipped silently without one:

```bash
# SSH end to end: uploads the generated script to a remote, runs it, and
# compares the parsed result against direct command output.
# Set SBM_E2E_SSH_HOST=<ssh destination or ~/.ssh/config alias> in the
# workspace-root .env first.
cargo test -p sbm_parser --test ssh_e2e

# Monitor terminal against a real sshd, rather than the in-process fake one
# in monitor/tests/fake_sshd/. Needs SBM_E2E_TERMINAL_*.
cargo test -p server_box_monitor --test terminal_ws
```

## Monitor Panel Tests

The monitor's Svelte frontend has its own suite (vitest +
@testing-library/svelte):

```bash
cd monitor/frontend
npm run test
npm run test:coverage

# Type gate, also part of `npm run build`
npm run check
```

## Unit Tests

Test business logic and data models:

```dart
test('should calculate CPU percentage', () {
  final cpu = CpuModel(usage: 75.0);
  expect(cpu.usagePercentage, '75%');
});
```

## Widget Tests

Test UI components:

```dart
testWidgets('ServerCard displays server name', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: ServerCard(server: testServer),
      ),
    ),
  );

  expect(find.text('Test Server'), findsOneWidget);
});
```

## Provider Tests

Test Riverpod providers:

```dart
test('serverStatusProvider returns status', () async {
  final container = ProviderContainer();
  final status = await container.read(serverStatusProvider(testServer).future);
  expect(status, isA<StatusModel>());
});
```

## Storage Migrations

A storage migration gets one pass over a user's real records, on one launch,
and it is not repeatable. Once the "done" marker is written, the old data is
never read again. A bug there is not a crash, it is silence: the records are
still on disk and the app no longer looks at them.

So every storage migration keeps a permanent regression test, against **bytes
written by the release being migrated from**, not by the current tree.
Permanent means the test is never retired once the migration ships; it runs and
finishes on every `flutter test`, like any other.

| File | Role |
|---|---|
| `test/hive_release_migration_test.dart` | Reads each fixture and asserts every store arrives intact |
| `test/fixtures/hive_v{1466,1480,1491}/` | The boxes those releases wrote, plus generators and a README |
| `test/hive_import_test.dart` | The import's own logic: retry, idempotency, per-box progress |

### Why the fixture, and not a hand-seeded box

Seeding through the current adapters only proves today's code is
self-consistent. It cannot catch a decoder that disagrees with what the old
release actually wrote, because both sides of the test are the same code.

That is not hypothetical. `hive_import_test.dart` seeded `Spi` through the
current adapter, which writes typeId 15 with the SSH fields nested. v1.0.1466
wrote typeId 3 with them flat. The path every upgrading install takes,
`SpiLegacyAdapter` decoding typeId 3 and `_toSpi` nesting it, had no coverage at
all until the fixture existed.

The fixture then exposed a second one on its first run: port forwards were
being lost **during import**. `PortForwardConfig` is the only freezed model in
the app with no `.g.dart`, so it has no generated `toJson`. Under Hive it
persisted through its typeId 10 adapter and never needed one. `SqliteStore.set`
encodes with `(value as dynamic).toJson()` and returns `false` instead of
throwing, so the failure was silent.

The import was only where it surfaced. `test/port_forward_store_test.dart`
establishes the rest independently: an ordinary save loses the record the same
way, with no migration involved.

Each covers one half, so both stay:

| Test | What it checks |
|---|---|
| `hive_release_migration_test.dart` | Records written by older releases import correctly |
| `port_forward_store_test.dart` | A write made by the current build persists and reads back |

### Adding one for the next migration

1. `git worktree add /tmp/<tag> <tag>`, init the submodules its `pubspec.yaml`
   needs, `flutter pub get`.
2. Copy the fixture generator from `test/fixtures/hive_v1466/gen_fixture.dart.txt` into a test, adapt it
   to that release's models, and make the data cover **every optional field,
   every enum case, and every stored type**, not one happy record. Include
   non-ASCII, quotes and newlines somewhere.
3. Run it, copy the output into `test/fixtures/<engine>_<tag>/`, remove the
   worktree.
4. Write the reading test against the current stores' public API, and assert
   the encoding too: read a row back out of the database and check no field of
   the old shape survived.

The generator is checked in as `.txt` because it is written against the old
release's APIs and would fail `flutter analyze` in this tree.

Never regenerate a fixture to make a failing test pass. It is the record of
what a shipped release wrote; editing it to suit the current decoder deletes
the only evidence that the decoder is wrong.

## External Dependencies

Keep `flutter test` deterministic: parser, model and command-builder tests must
not need a network or a real server. Add targeted fakes or fixtures when a
feature introduces a service boundary.

The Rust suites listed under "Opt-in tests" above are the exception. They are
skipped unless their environment variables are set, so a default
`cargo test --workspace` still needs nothing.

## Integration Tests

`integration_test/` holds what `flutter test` cannot answer. The unit suite runs
under `flutter_tester`, which loads no plugins. Anything reached through a
plugin or FFI has never actually run there. These run inside a real app on a
real device:

| File | Question |
|---|---|
| `local_shell_test.dart` | Does a shell on this device actually spawn |
| `rootfs_shell_test.dart` | The Linux userland, through the API the app uses |
| `android_exec_test.dart` | What Android will execute out of the app's own directory |
| `android_rootfs_test.dart` | Whether the Android guest mechanism can work at all |
| `ios_rootfs_test.dart` | The Linux userland on iOS |
| `ios_bench_test.dart` | What the Linux guest costs on real hardware |
| `ios_load_test.dart` | What the guest costs the app while it is working |
| `sandbox_import_test.dart` | Taking over the sandboxed build's data |

```bash
# Needs a connected device or simulator; flutter test alone does not run these
flutter test integration_test/local_shell_test.dart
```

They live outside `test/` because `flutter test` with no argument runs
everything in there. Device tests placed among the unit suite would be picked
up by every local run and by CI, where there is no device.

`make analyze` covers this directory too (`flutter analyze lib test
integration_test`).

### The one device `flutter test` cannot reach

When Xcode reaches an iOS 17+ device over the network rather than by cable,
`flutter test` cannot launch the app at all: it hardcodes
`disablePortPublication: true`, `IOSDevice.startApp` refuses a wirelessly
tethered device when that is set, and there is no flag to clear it.
`flutter drive --publish-port` is the same run with the bit cleared, which is
what `integration_test/driver.dart` exists for:

```bash
flutter drive --publish-port \
  --driver=integration_test/driver.dart \
  --target=integration_test/ios_rootfs_test.dart
```

The device answers `--publish-port` with the local-network permission dialog on
first use, which someone has to allow.

## Best Practices

1. **Arrange-Act-Assert**: Structure tests clearly
2. **Descriptive names**: Test names should describe behavior
3. **Focused tests**: Keep each test focused; use as many assertions as needed to verify its behavior
4. **Mock external deps**: Don't depend on real servers
5. **Test edge cases**: Empty lists, null values, etc.
