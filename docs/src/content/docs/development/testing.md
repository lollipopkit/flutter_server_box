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

Tests are located in the `test/` directory mirroring the lib structure:

```
test/
├── data/
│   ├── model/
│   └── provider/
├── view/
│   └── widget/
└── test_helpers.dart
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

## Mocking

Use mocks for external dependencies:

```dart
class MockSshService extends Mock implements SshService {}

test('connects to server', () async {
  final mockSsh = MockSshService();
  when(mockSsh.connect(any)).thenAnswer((_) async => true);

  // Test with mock
});
```

## Integration Tests

Test complete user flows (in `integration_test/`):

```dart
testWidgets('add server flow', (tester) async {
  await tester.pumpWidget(MyApp());

  // Tap add button
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  // Fill form
  await tester.enterText(find.byKey(Key('name')), 'Test Server');
  // ...
});
```

## Best Practices

1. **Arrange-Act-Assert**: Structure tests clearly
2. **Descriptive names**: Test names should describe behavior
3. **One assertion per test**: Keep tests focused
4. **Mock external deps**: Don't depend on real servers
5. **Test edge cases**: Empty lists, null values, etc.
