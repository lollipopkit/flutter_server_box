---
title: Testing
description: Testing strategies and running tests
---

## Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/battery_test.dart

# Run with coverage
flutter test --coverage
```

## Test Structure

Tests are located in the `test/` directory. The current suite is mostly flat and grouped by parser, model, and utility behavior, for example `cpu_test.dart`, `container_test.dart`, and `ssh_config_test.dart`.

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
