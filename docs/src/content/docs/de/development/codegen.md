---
title: Codegenerierung
description: Verwendung von build_runner für die Codegenerierung
---

Server Box verwendet intensiv Codegenerierung für Modelle, Zustandsverwaltung und Serialisierung.

## Wann sollte die Codegenerierung ausgeführt werden?

Führen Sie sie aus nach der Änderung von:

- Modellen mit `@freezed` Annotation
- Klassen mit `@JsonSerializable`
- Hive-Modellen
- Providern mit `@riverpod`
- Lokalisierungen (ARB-Dateien)

## Codegenerierung ausführen

```bash
# Gesamten Code generieren
dart run build_runner build --delete-conflicting-outputs

# Generierten Build-Cache bereinigen
dart run build_runner clean

# Dann neu generieren
dart run build_runner build --delete-conflicting-outputs
```

## Generierte Dateien

### Freezed (`*.freezed.dart`)

Unveränderliche Datenmodelle mit Union Types:

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### JSON-Serialisierung (`*.g.dart`)

Generiert durch `json_serializable`:

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

### Riverpod Provider (`*.g.dart`)

Generiert aus der `@riverpod` Annotation:

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### Hive-Adapter (`*.g.dart`)

Automatisch generiert für Hive-Modelle (hive_ce):

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```

## Generierung der Lokalisierung

```bash
flutter gen-l10n
```

Generiert `lib/generated/l10n/` aus `lib/l10n/*.arb` Dateien.

## Tipps

- Verwenden Sie `--delete-conflicting-outputs`, um Konflikte zu vermeiden.
- Behalten Sie generierte Dateien in der Versionsverwaltung, wenn dieses Repository sie bereits verfolgt.
- Bearbeiten Sie generierte Dateien niemals manuell.
