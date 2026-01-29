---
title: Pruebas
description: Estrategias de prueba y ejecución de pruebas
---

## Ejecución de Pruebas

```bash
# Ejecutar todas las pruebas
flutter test

# Ejecutar un archivo de prueba específico
flutter test test/battery_test.dart

# Ejecutar con cobertura
flutter test --coverage
```

## Estructura de las Pruebas

Las pruebas se encuentran en el directorio `test/` reflejando la estructura de lib:

```
test/
├── data/
│   ├── model/
│   └── provider/
├── view/
│   └── widget/
└── test_helpers.dart
```

## Pruebas Unitarias

Probar la lógica de negocio y los modelos de datos:

```dart
test('debería calcular el porcentaje de CPU', () {
  final cpu = CpuModel(usage: 75.0);
  expect(cpu.usagePercentage, '75%');
});
```

## Pruebas de Widgets

Probar componentes de la interfaz de usuario (UI):

```dart
testWidgets('ServerCard muestra el nombre del servidor', (tester) async {
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

## Pruebas de Providers

Probar providers de Riverpod:

```dart
test('serverStatusProvider devuelve el estado', () async {
  final container = ProviderContainer();
  final status = await container.read(serverStatusProvider(testServer).future);
  expect(status, isA<StatusModel>());
});
```

## Mocking (Simulaciones)

Utilizar mocks para dependencias externas:

```dart
class MockSshService extends Mock implements SshService {}

test('se conecta al servidor', () async {
  final mockSsh = MockSshService();
  when(mockSsh.connect(any)).thenAnswer((_) async => true);

  // Probar con el mock
});
```

## Pruebas de Integración

Probar flujos de usuario completos (en `integration_test/`):

```dart
testWidgets('flujo de agregar servidor', (tester) async {
  await tester.pumpWidget(MyApp());

  // Tocar el botón de agregar
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  // Completar el formulario
  await tester.enterText(find.byKey(Key('name')), 'Test Server');
  // ...
});
```

## Buenas Prácticas

1. **Arrange-Act-Assert**: Estructurar las pruebas claramente.
2. **Nombres descriptivos**: Los nombres de las pruebas deben describir el comportamiento.
3. **Una aserción por prueba**: Mantener las pruebas enfocadas.
4. **Simular dependencias externas**: No depender de servidores reales.
5. **Probar casos límite**: Listas vacías, valores nulos, etc.
