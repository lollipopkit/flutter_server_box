---
title: Code Generation
description: Using build_runner for code generation
---

Server Box heavily uses code generation for models, state management, and serialization.

## When to Run Code Generation

Run after modifying:

- Models with `@freezed` annotation
- Classes with `@JsonSerializable`
- Hive models
- Providers with `@riverpod`
- Localizations (ARB files)

## Running Code Generation

```bash
# Generate all code
dart run build_runner build --delete-conflicting-outputs

# Clean and regenerate
dart run build_runner build --delete-conflicting-outputs --clean
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

Generated from `json_serializable`:

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

Auto-generated for Hive models (hive_ce):

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```

## Localization Generation

```bash
flutter gen-l10n
```

Generates `lib/generated/l10n/` from `lib/l10n/*.arb` files.

## Tips

- Use `--delete-conflicting-outputs` to avoid conflicts
- Add generated files to `.gitignore`
- Never manually edit generated files
