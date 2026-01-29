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

Les tests sont situés dans le répertoire `test/`, reflétant la structure de `lib/` :

```
test/
├── data/
│   ├── model/
│   └── provider/
├── view/
│   └── widget/
└── test_helpers.dart
```

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

## Mocking (Simulations)

Utiliser des mocks pour les dépendances externes :

```dart
class MockSshService extends Mock implements SshService {}

test('se connecte au serveur', () async {
  final mockSsh = MockSshService();
  when(mockSsh.connect(any)).thenAnswer((_) async => true);

  // Tester avec le mock
});
```

## Tests d'intégration

Tester des flux utilisateurs complets (dans `integration_test/`) :

```dart
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
