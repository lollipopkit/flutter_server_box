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

Avoid tests that depend on real SSH servers. Keep parser, model, and command-builder tests deterministic; add targeted fakes or fixtures when a feature introduces a service boundary.

## Integration Tests

There is no `integration_test/` suite in the current repository. Add integration tests only when a feature needs end-to-end device or app-flow coverage.

## Best Practices

1. **Arrange-Act-Assert**: Structure tests clearly
2. **Descriptive names**: Test names should describe behavior
3. **One assertion per test**: Keep tests focused
4. **Mock external deps**: Don't depend on real servers
5. **Test edge cases**: Empty lists, null values, etc.
