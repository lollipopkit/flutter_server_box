---
title: テスト
description: テスト戦略とテストの実行
---

## テストの実行

```bash
# すべてのテストを実行
flutter test

# 特定のテストファイルを実行
flutter test test/battery_test.dart

# カバレッジ付きで実行
flutter test --coverage
```

## テスト構造

テストは `test/` ディレクトリにあります。現在のテストスイートは主にフラットな構成で、パーサー、モデル、ユーティリティの挙動ごとに分かれています。例: `cpu_test.dart`、`container_test.dart`、`ssh_config_test.dart`。

## ユニットテスト

ビジネスロジックとデータモデルのテスト：

```dart
test('CPU使用率を計算する必要があります', () {
  final cpu = CpuModel(usage: 75.0);
  expect(cpu.usagePercentage, '75%');
});
```

## ウィジェットテスト

UI コンポーネントのテスト：

```dart
testWidgets('ServerCard にサーバー名が表示されること', (tester) async {
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

## プロバイダーテスト

Riverpod プロバイダーのテスト：

```dart
test('serverStatusProvider がステータスを返すこと', () async {
  final container = ProviderContainer();
  final status = await container.read(serverStatusProvider(testServer).future);
  expect(status, isA<StatusModel>());
});
```

## 外部依存

実際の SSH サーバーに依存するテストは避けてください。パーサー、モデル、コマンドビルダーのテストは決定的に保ち、機能がサービス境界を導入する場合にのみ対象を絞った fake や fixture を追加してください。

## 統合テスト

現在のリポジトリには `integration_test/` スイートはありません。デバイス上の end-to-end やアプリ全体のフロー確認が必要な機能でのみ追加してください。dart
testWidgets('サーバー追加フロー', (tester) async {
  await tester.pumpWidget(MyApp());

  // 追加ボタンをタップ
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  // フォームを入力
  await tester.enterText(find.byKey(Key('name')), 'Test Server');
  // ...
});
```

## ベストプラクティス

1. **Arrange-Act-Assert**: テストを明確に構造化する
2. **記述的な名前**: テスト名は動作を記述する必要がある
3. **1つのテストに1つのアサーション**: テストの焦点を絞る
4. **外部依存関係をモックする**: 実際のサーバーに依存しない
5. **エッジケースのテスト**: 空のリスト、null 値など
