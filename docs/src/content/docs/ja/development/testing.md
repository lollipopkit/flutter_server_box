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

テストは `test/` ディレクトリにあり、lib の構造を反映しています：

```
test/
├── data/
│   ├── model/
│   └── provider/
├── view/
│   └── widget/
└── test_helpers.dart
```

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

## モック (Mocking)

外部依存関係にモックを使用する：

```dart
class MockSshService extends Mock implements SshService {}

test('サーバーに接続すること', () async {
  final mockSsh = MockSshService();
  when(mockSsh.connect(any)).thenAnswer((_) async => true);

  // モックを使用してテスト
});
```

## 統合テスト

完全なユーザーフローのテスト (`integration_test/` 内)：

```dart
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
