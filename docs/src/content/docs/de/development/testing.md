---
title: Testen
description: Teststrategien und Ausführung von Tests
---

## Tests ausführen

```bash
# Alle Tests ausführen
flutter test

# Bestimmte Testdatei ausführen
flutter test test/disk_test.dart

# Mit Coverage ausführen
flutter test --coverage
```

## Teststruktur

Tests befinden sich im Verzeichnis `test/`. Die aktuelle Suite ist überwiegend flach und nach Parser-, Modell- und Utility-Verhalten gruppiert, zum Beispiel `disk_test.dart`, `container_test.dart` und `ssh_config_test.dart`.

## Rust-Tests

Das Status-Parsing liegt im gemeinsamen Rust-Workspace:

```bash
# Alle Rust-Tests (Parser, nativer Sampler, FFI-Hülle, Monitor)
cargo test --workspace

# FFI-Paritätstest: stellt sicher, dass die Dart-Seite über
# flutter_rust_bridge identische Ergebnisse erhält (FFI-Crate zuerst bauen)
cargo build -p sbm_ffi
flutter test test/frb_parser_test.dart
```

`crates/sbm_parser/tests/dart_compat.rs` fixiert das Parser-Verhalten gegen die ursprüngliche Dart-Fixture-Suite.

### Tests mit Opt-in

Zwei Suiten brauchen einen echten Host und werden ohne ihn still übersprungen:

```bash
# SSH von Ende zu Ende: lädt das generierte Skript auf einen entfernten Host,
# führt es aus und vergleicht das geparste Ergebnis mit der direkten
# Befehlsausgabe. Zuvor SBM_E2E_SSH_HOST=<SSH-Ziel oder ~/.ssh/config-Alias>
# in der .env im Workspace-Wurzelverzeichnis setzen.
cargo test -p sbm_parser --test ssh_e2e

# Monitor-Terminal gegen einen echten sshd statt gegen den In-Process-Fake in
# monitor/tests/fake_sshd/. Benötigt SBM_E2E_TERMINAL_*.
cargo test -p server_box_monitor --test terminal_ws
```

## Tests des Monitor-Panels

Das Svelte-Frontend des Monitors hat eine eigene Suite (vitest +
@testing-library/svelte):

```bash
cd monitor/frontend
npm run test
npm run test:coverage

# Typprüfung, auch Teil von `npm run build`
npm run check
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

## Externe Abhängigkeiten

Vermeiden Sie Tests, die von echten SSH-Servern abhängen. Parser-, Modell- und Command-Builder-Tests sollten deterministisch bleiben; fügen Sie gezielte Fakes oder Fixtures hinzu, wenn eine Funktion eine Service-Grenze einführt.

## Integrationstests

Im aktuellen Repository gibt es keine `integration_test/`-Suite. Fügen Sie Integrationstests nur hinzu, wenn eine Funktion End-to-End-Geräte- oder App-Flow-Abdeckung benötigt.dart
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
