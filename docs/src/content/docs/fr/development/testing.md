---
title: Tests
description: Stratégies de test et exécution des tests
---

## Exécuter les tests

```bash
# Exécuter tous les tests
flutter test

# Exécuter un fichier de test spécifique
flutter test test/disk_test.dart

# Exécuter avec couverture de code
flutter test --coverage
```

## Structure des tests

Les tests se trouvent dans le répertoire `test/`. La suite actuelle est principalement plate et regroupée par comportement de parseur, de modèle et d’utilitaire, par exemple `disk_test.dart`, `container_test.dart` et `ssh_config_test.dart`.

## Tests Rust

L'analyse d'état vit dans le workspace Rust partagé :

```bash
# Tous les tests Rust (parseur, échantillonneur natif, coquille FFI, monitor)
cargo test --workspace

# Test de parité FFI : vérifie que le côté Dart obtient des résultats
# identiques via flutter_rust_bridge (compiler d'abord le crate FFI)
cargo build -p sbm_ffi
flutter test test/frb_parser_test.dart
```

`crates/sbm_parser/tests/dart_compat.rs` fige le comportement du parseur par rapport à la suite de fixtures Dart d'origine.

### Tests optionnels

Deux suites demandent un hôte réel et sont ignorées silencieusement sans lui :

```bash
# SSH de bout en bout : téléverse le script généré sur un hôte distant,
# l'exécute et compare le résultat analysé à la sortie directe des commandes.
# Définir d'abord SBM_E2E_SSH_HOST=<destination ssh ou alias ~/.ssh/config>
# dans le .env à la racine du workspace.
cargo test -p sbm_parser --test ssh_e2e

# Terminal du monitor face à un vrai sshd, plutôt qu'au faux en mémoire de
# monitor/tests/fake_sshd/. Nécessite SBM_E2E_TERMINAL_*.
cargo test -p server_box_monitor --test terminal_ws
```

## Tests du panneau monitor

Le frontend Svelte du monitor possède sa propre suite (vitest +
@testing-library/svelte) :

```bash
cd monitor/frontend
npm run test
npm run test:coverage

# Vérification de types, également incluse dans `npm run build`
npm run check
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
