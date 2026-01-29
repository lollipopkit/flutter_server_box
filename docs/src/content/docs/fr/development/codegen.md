---
title: Génération de code
description: Utiliser build_runner pour la génération de code
---

Server Box utilise intensivement la génération de code pour les modèles, la gestion de l'état et la sérialisation.

## Quand exécuter la génération de code

À exécuter après avoir modifié :

- Des modèles avec l'annotation `@freezed`
- Des classes avec `@JsonSerializable`
- Des modèles Hive
- Des providers avec `@riverpod`
- Des localisations (fichiers ARB)

## Exécuter la génération de code

```bash
# Générer tout le code
dart run build_runner build --delete-conflicting-outputs

# Nettoyer et régénérer
dart run build_runner build --delete-conflicting-outputs --clean
```

## Fichiers générés

### Freezed (`*.freezed.dart`)

Modèles de données immuables avec types Union :

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### Sérialisation JSON (`*.g.dart`)

Généré à partir de `json_serializable` :

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

### Providers Riverpod (`*.g.dart`)

Généré à partir de l'annotation `@riverpod` :

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### Adaptateurs Hive (`*.g.dart`)

Auto-générés pour les modèles Hive (hive_ce) :

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```

## Génération de localisation

```bash
flutter gen-l10n
```

Génère `lib/generated/l10n/` à partir des fichiers `lib/l10n/*.arb`.

## Conseils

- Utilisez `--delete-conflicting-outputs` pour éviter les conflits
- Ajoutez les fichiers générés au `.gitignore`
- Ne modifiez jamais manuellement les fichiers générés
