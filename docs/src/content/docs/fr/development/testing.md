---
title: Tests
description: Stratégies de test et exécution des tests
---

## Exécuter les tests

```bash
# Exécuter tous les tests
flutter test

# Exécuter un fichier de test spécifique
flutter test test/battery_test.dart

# Exécuter avec couverture de code
flutter test --coverage
```

## Structure des tests

Les tests se trouvent dans le répertoire `test/`. La suite actuelle est principalement plate et regroupée par comportement de parseur, de modèle et d’utilitaire, par exemple `cpu_test.dart`, `container_test.dart` et `ssh_config_test.dart`.

## Tests unitaires

Tester la logique métier et les modèles de données :

```dart
test('devrait calculer le pourcentage du CPU', () {
  final cpu = CpuModel(usage: 75.0);
  expect(cpu.usagePercentage, '75%');
});
```

## Tests de widgets

Tester les composants UI :

```dart
testWidgets('ServerCard affiche le nom du serveur', (tester) async {
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

## Tests de providers

Tester les providers Riverpod :

```dart
test('serverStatusProvider retourne le statut', () async {
  final container = ProviderContainer();
  final status = await container.read(serverStatusProvider(testServer).future);
  expect(status, isA<StatusModel>());
});
```

## Dépendances externes

Évitez les tests qui dépendent de vrais serveurs SSH. Les tests de parseurs, modèles et constructeurs de commandes doivent rester déterministes ; ajoutez des fakes ou fixtures ciblés lorsqu’une fonctionnalité introduit une frontière de service.

## Tests d'intégration

Le dépôt actuel ne contient pas de suite `integration_test/`. Ajoutez des tests d’intégration seulement lorsqu’une fonctionnalité nécessite une couverture end-to-end sur appareil ou flux applicatif complet.dart
testWidgets('flux d\'ajout de serveur', (tester) async {
  await tester.pumpWidget(MyApp());

  // Appuyer sur le bouton d'ajout
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  // Remplir le formulaire
  await tester.enterText(find.byKey(Key('name')), 'Test Server');
  // ...
});
```

## Bonnes pratiques

1. **Arrange-Act-Assert** : Structurer les tests clairement
2. **Noms descriptifs** : Les noms de tests doivent décrire le comportement
3. **Une assertion par test** : Garder les tests focalisés
4. **Mocker les dépendances externes** : Ne pas dépendre de serveurs réels
5. **Tester les cas limites** : Listes vides, valeurs nulles, etc.
