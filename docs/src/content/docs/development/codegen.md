---
title: Code Generation
description: Generate Dart, Flutter, and Rust binding code
---

Server Box uses code generation for immutable models, JSON serialization, Riverpod providers, legacy Hive adapters, localization, and Rust bindings.

## When to run code generation

Run the relevant generator after modifying:

- Models with `@freezed`
- Classes with `@JsonSerializable`
- Hive models in the current generated-adapter list
- Providers with `@riverpod`
- ARB localization files
- Rust APIs under `crates/sbm_ffi/src/api`

The frozen adapters in `lib/hive/legacy_adapters.dart` are not part of the generated list. They read boxes written by old releases and must not be regenerated from current models.

## Dart generation

### Normal generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Clean and regenerate

Use this only when the build cache is inconsistent:

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

## Generated files

### Freezed (`*.freezed.dart`)

Freezed generates immutable models, `copyWith`, equality, and union APIs:

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### JSON serialization (`*.g.dart`)

`json_serializable` generates `fromJson` and `toJson` methods from model fields:

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

### Riverpod providers (`*.g.dart`)

`riverpod_generator` creates providers from `@riverpod` declarations:

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### Hive adapters (`*.g.dart`)

Generated adapters cover only models that remain in the current adapter list:

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```

Adapters in `lib/hive/legacy_adapters.dart` are intentionally frozen readers. Do not regenerate them from current models or add models with new fields to the legacy generated list: old boxes do not contain those fields, and a new non-nullable field can prevent an old box from opening. Change a frozen reader only when bytes written by a released version require it, and update the migration test with it.

## Rust bindings (flutter_rust_bridge)

After changing `crates/sbm_ffi/src/api`, regenerate Dart bindings:

```bash
flutter_rust_bridge_codegen generate
```

Configuration is in `flutter_rust_bridge.yaml`; output is written to `lib/src/rust/`. Do not edit generated files. Do not run `flutter_rust_bridge_codegen integrate`; it creates template scaffolding that does not match this repository.

## Localization generation

After changing `lib/l10n/*.arb`, run:

```bash
flutter gen-l10n
```

The generated code is written to `lib/generated/l10n/`.

## Notes

- Use `--delete-conflicting-outputs` when generated files conflict.
- Commit generated files that are tracked by this repository.
- Never manually edit `*.g.dart`, `*.freezed.dart`, or files under `lib/generated/`.
- Finish code generation before running analyze and tests after a model change.
