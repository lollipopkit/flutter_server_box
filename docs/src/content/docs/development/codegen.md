---
title: Code Generation
description: Generate Dart, Flutter, and Rust binding code
---

The project generates immutable model code, JSON serializers, Riverpod
providers, Hive adapters, localization code, and Rust bindings. Run the
generator that matches the source you changed.

## When to run code generation

Run code generation after changing any of these inputs:

- Models with `@freezed`
- Classes with `@JsonSerializable`
- Hive models in the current generated-adapter list
- Providers with `@riverpod`
- ARB localization files
- Rust APIs under `crates/sbm_ffi/src/api`

The frozen adapters in `lib/hive/legacy_adapters.dart` are excluded from the
generated adapter list. They read boxes created by earlier releases; do not
regenerate them from current models.

## Dart generation

### Normal generation

```bash
dart run build_runner build
```

### Clean and regenerate

Use a clean build when the cached asset graph is out of sync with the source
tree, for example after merging generated source files. A stale
`.dart_tool/build/asset_graph.json` can cause build_runner to stall midway
through a phase without reporting a useful error.

```bash
dart run build_runner clean
dart run build_runner build
```

## Generated files

### Freezed (`*.freezed.dart`)

Freezed produces immutable model implementations, `copyWith`, equality, and
union APIs:

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### JSON serialization (`*.g.dart`)

`json_serializable` creates `fromJson` and `toJson` methods based on model
fields:

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

`riverpod_generator` creates provider declarations from `@riverpod` classes:

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### Hive adapters (`*.g.dart`)

Hive adapter generation includes only models in the current generated list:

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```

Adapters in `lib/hive/legacy_adapters.dart` are frozen readers. Do not
regenerate them from current models or add a model with new fields to the
legacy generated list. Old boxes do not contain those fields, and a new
non-nullable field can make an old box unreadable. Change a frozen reader only
when data written by a released version requires it, and update its migration
test at the same time.

## Rust bindings (flutter_rust_bridge)

After editing a Rust API under `crates/sbm_ffi/src/api`, regenerate its Dart
bindings:

```bash
flutter_rust_bridge_codegen generate
```

The generator reads `flutter_rust_bridge.yaml` and writes files to
`lib/src/rust/`. Do not edit those generated files. Do not run
`flutter_rust_bridge_codegen integrate`; its template scaffolding does not
match this repository.

## Localization generation

After editing a localization file in `lib/l10n/*.arb`, run:

```bash
flutter gen-l10n
```

Generated localization code is written to `lib/generated/l10n/`.

## Notes

- build_runner 2.15 removed `--delete-conflicting-outputs`; it now prints a warning and has no effect. Clear the cache as described above instead.
- Include generated files in your change when this repository tracks them.
- Do not edit `*.g.dart`, `*.freezed.dart`, or files under `lib/generated/` by hand.
- After changing a model, complete generation before running analysis and tests.
