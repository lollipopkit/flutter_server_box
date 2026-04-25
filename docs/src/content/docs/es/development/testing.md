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

Las pruebas se encuentran en el directorio `test/`. La suite actual es mayormente plana y se agrupa por comportamiento de parsers, modelos y utilidades, por ejemplo `cpu_test.dart`, `container_test.dart` y `ssh_config_test.dart`.

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

## Dependencias externas

Evita pruebas que dependan de servidores SSH reales. Las pruebas de parsers, modelos y constructores de comandos deben ser deterministas; añade fakes o fixtures dirigidos cuando una función introduzca una frontera de servicio.

## Pruebas de Integración

El repositorio actual no contiene una suite `integration_test/`. Añade pruebas de integración solo cuando una función necesite cobertura end-to-end de dispositivo o flujo completo de la app.dart
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
