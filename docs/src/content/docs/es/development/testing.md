---
title: Pruebas
description: Estrategias de prueba y ejecución de pruebas
---

## Ejecución de Pruebas

```bash
# Ejecutar todas las pruebas
flutter test

# Ejecutar un archivo de prueba específico
flutter test test/disk_test.dart

# Ejecutar con cobertura
flutter test --coverage
```

## Estructura de las Pruebas

Las pruebas se encuentran en el directorio `test/`. La suite actual es mayormente plana y se agrupa por comportamiento de parsers, modelos y utilidades, por ejemplo `disk_test.dart`, `container_test.dart` y `ssh_config_test.dart`.

## Pruebas de Rust

El análisis de estado vive en el workspace de Rust compartido:

```bash
# Todas las pruebas de Rust (parser, capa FFI, monitor)
cargo test --workspace

# Prueba de paridad FFI: verifica que el lado Dart obtiene resultados
# idénticos vía flutter_rust_bridge (compila primero el crate FFI)
cargo build -p sbm_ffi
flutter test test/frb_parser_test.dart
```

`crates/sbm_parser/tests/dart_compat.rs` fija el comportamiento del parser contra la suite de fixtures Dart original.

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

El repositorio actual no contiene una suite `integration_test/`. Añade pruebas de integración solo cuando una función necesite cobertura end-to-end de dispositivo o flujo completo de la app.

## Buenas Prácticas

1. **Arrange-Act-Assert**: Estructurar las pruebas claramente.
2. **Nombres descriptivos**: Los nombres de las pruebas deben describir el comportamiento.
3. **Una aserción por prueba**: Mantener las pruebas enfocadas.
4. **Simular dependencias externas**: No depender de servidores reales.
5. **Probar casos límite**: Listas vacías, valores nulos, etc.
