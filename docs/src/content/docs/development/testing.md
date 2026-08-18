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

## External Dependencies

Keep `flutter test` deterministic: parser, model and command-builder tests must
not need a network or a real server. Add targeted fakes or fixtures when a
feature introduces a service boundary.

The Rust suites listed under "Opt-in tests" above are the exception. They are
skipped unless their environment variables are set, so a default
`cargo test --workspace` still needs nothing.

## Integration Tests

`integration_test/` holds what `flutter test` cannot answer. The unit suite runs
under `flutter_tester`, which loads no plugins — so anything reached through a
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

`make analyze` covers this directory too (`flutter analyze lib test
integration_test`).

## Best Practices

1. **Arrange-Act-Assert**: Structure tests clearly
2. **Descriptive names**: Test names should describe behavior
3. **One assertion per test**: Keep tests focused
4. **Mock external deps**: Don't depend on real servers
5. **Test edge cases**: Empty lists, null values, etc.
