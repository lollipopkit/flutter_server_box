---
title: Code Generation
description: Using build_runner for code generation
---

Server Box uses code generation for models, state management, and serialization.

## When to Run Code Generation

Run the relevant generator after modifying:

- Models with `@freezed` annotation
- Classes with `@JsonSerializable`
- Hive adapter sources in the current generated adapter list (not frozen legacy
  readers)
- Providers with `@riverpod`
- Localization ARB files; run `flutter gen-l10n`

## Running Code Generation

```bash
# Generate all code
dart run build_runner build --delete-conflicting-outputs

# Clear the build_runner cache
dart run build_runner clean

# Then regenerate
dart run build_runner build --delete-conflicting-outputs
```

## Generated Files

### Freezed (`*.freezed.dart`)

Immutable data models with union types:

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### JSON Serialization (`*.g.dart`)

The `json_serializable` package generates these files:

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

### Riverpod Providers (`*.g.dart`)

Generated from `@riverpod` annotation:

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### Hive Adapters (`*.g.dart`)

Generated Hive adapters cover the current adapter list:

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```

The adapters in `lib/hive/legacy_adapters.dart` are intentionally frozen readers.
Do not regenerate them from current models or add a newly changed model to the
generated adapter list: a newly added non-nullable field can make boxes written
by older releases fail to open. Update a frozen reader and its migration test
only when the bytes written by a released version require it.

## Rust Bindings (flutter_rust_bridge)

After changing `crates/sbm_ffi/src/api`, regenerate the Dart bindings:

```bash
flutter_rust_bridge_codegen generate
```

Config lives in `flutter_rust_bridge.yaml`; output goes to `lib/src/rust/`
(never edit generated files there).

## Localization Generation

```bash
flutter gen-l10n
```

Generates `lib/generated/l10n/` from `lib/l10n/*.arb` files.

## Tips

- Use `--delete-conflicting-outputs` to avoid conflicts
- Commit generated files that are already tracked by this repository
- Never manually edit generated files
