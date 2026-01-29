---
title: Generación de Código
description: Uso de build_runner para la generación de código
---

Flutter Server Box utiliza intensivamente la generación de código para modelos, gestión de estado y serialización.

## Cuándo Ejecutar la Generación de Código

Ejecutar tras modificar:

- Modelos con la anotación `@freezed`
- Clases con `@JsonSerializable`
- Modelos de Hive
- Providers con `@riverpod`
- Localizaciones (archivos ARB)

## Ejecutar la Generación de Código

```bash
# Generar todo el código
dart run build_runner build --delete-conflicting-outputs

# Limpiar y regenerar
dart run build_runner build --delete-conflicting-outputs --clean
```

## Archivos Generados

### Freezed (`*.freezed.dart`)

Modelos de datos inmutables con tipos Union:

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### Serialización JSON (`*.g.dart`)

Generado por `json_serializable`:

```dart
@JsonSerializable()
class Server {
  final String id;
  final String name;
  final String host;

  Server({required this.id, required this.name, required this.host});

  factory Server.fromJson(Map<String, dynamic> json) =>
      _$ServerFromJson(json);
  Map<String, dynamic> toJson() => _$ServerToJson(this);
}
```

### Providers de Riverpod (`*.g.dart`)

Generados a partir de la anotación `@riverpod`:

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### Adaptadores de Hive (`*.g.dart`)

Auto-generados para modelos de Hive (hive_ce):

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```

## Generación de Localización

```bash
flutter gen-l10n
```

Genera `lib/generated/l10n/` a partir de los archivos `lib/l10n/*.arb`.

## Consejos

- Usa `--delete-conflicting-outputs` para evitar conflictos
- Añade los archivos generados al `.gitignore`
- Nunca edites manualmente los archivos generados
