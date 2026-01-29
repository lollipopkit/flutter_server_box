---
title: Testen
description: Teststrategien und Ausführung von Tests
---

## Tests ausführen

```bash
# Alle Tests ausführen
flutter test

# Bestimmte Testdatei ausführen
flutter test test/battery_test.dart

# Mit Coverage ausführen
flutter test --coverage
```

## Teststruktur

Tests befinden sich im Verzeichnis `test/` und spiegeln die Struktur von `lib/` wider:

```
test/
├── data/
│   ├── model/
│   └── provider/
├── view/
│   └── widget/
└── test_helpers.dart
```

## Unit-Tests

Geschäftslogik und Datenmodelle testen:

```dart
test('sollte CPU-Prozentsatz berechnen', () {
  final cpu = CpuModel(usage: 75.0);
  expect(cpu.usagePercentage, '75%');
});
```

## Widget-Tests

UI-Komponenten testen:

```dart
testWidgets('ServerCard zeigt Servernamen an', (tester) async {
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

## Provider-Tests

Riverpod Provider testen:

```dart
test('serverStatusProvider gibt Status zurück', () async {
  final container = ProviderContainer();
  final status = await container.read(serverStatusProvider(testServer).future);
  expect(status, isA<StatusModel>());
});
```

## Mocking

Mocks für externe Abhängigkeiten verwenden:

```dart
class MockSshService extends Mock implements SshService {}

test('verbindet zum Server', () async {
  final mockSsh = MockSshService();
  when(mockSsh.connect(any)).thenAnswer((_) async => true);

  // Test mit Mock
});
```

## Integrationstests

Komplette Benutzerabläufe testen (in `integration_test/`):

```dart
testWidgets('Server hinzufügen Ablauf', (tester) async {
  await tester.pumpWidget(MyApp());

  // Hinzufügen-Button tippen
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  // Formular ausfüllen
  await tester.enterText(find.byKey(Key('name')), 'Test Server');
  // ...
});
```

## Best Practices

1. **Arrange-Act-Assert**: Tests klar strukturieren
2. **Beschreibende Namen**: Testnamen sollten das Verhalten beschreiben
3. **Eine Assertion pro Test**: Tests fokussiert halten
4. **Externe Abhängigkeiten mocken**: Nicht von echten Servern abhängig sein
5. **Grenzfälle testen**: Leere Listen, Null-Werte, usw.
