---
title: 状態管理
description: Riverpod を使用した状態管理の仕組み
---

Flutter Server Box における状態管理アーキテクチャについて解説します。

## なぜ Riverpod なのか？

**主な利点:**
- **コンパイル時の安全性**: エラーをコンパイル時に検知可能
- **BuildContext が不要**: どこからでも状態にアクセス可能
- **テストの容易さ**: Provider を単体で簡単にテスト可能
- **コード生成**: ボイラープレートを削減し、型安全性を確保

## Provider アーキテクチャ

```
┌─────────────────────────────────────────────┐
│          UI レイヤー (Widget)               │
│  - ConsumerWidget / ConsumerStatefulWidget  │
│  - ref.watch() / ref.read()                 │
└─────────────────────────────────────────────┘
                ↓ 監視 (watch)
┌─────────────────────────────────────────────┐
│          Provider レイヤー                  │
│  - @riverpod アノテーション                 │
│  - 生成された *.g.dart ファイル              │
└─────────────────────────────────────────────┘
                ↓ 使用 (use)
┌─────────────────────────────────────────────┐
│          Service / Store レイヤー           │
│  - ビジネスロジック                         │
│  - データアクセス                           │
└─────────────────────────────────────────────┘
```

## 使用されている Provider の種類

### 1. StateProvider (単純な状態)

単純で観察可能な状態に使用します。

```dart
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeMode build() {
    // 設定からロード
    return SettingStore.themeMode;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    SettingStore.themeMode = mode;  // 永続化
  }
}
```

**使い方:**
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    return Text('現在のテーマ: $theme');
  }
}
```

### 2. AsyncNotifierProvider (非同期状態)

非同期にロードされるデータに使用します。

```dart
@riverpod
class ServerStatus extends _$ServerStatus {
  @override
  Future<StatusModel> build(Server server) async {
    // 初回ロード
    return await fetchStatus(server);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await fetchStatus(server);
    });
  }
}
```

**使い方:**
```dart
final status = ref.watch(serverStatusProvider(server));

status.when(
  data: (data) => StatusWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 3. StreamProvider (リアルタイムデータ)

継続的なデータストリームに使用します。

```dart
@riverpod
Stream<CpuUsage> cpuUsage(CpuUsageRef ref, Server server) {
  final client = ref.watch(sshClientProvider(server));
  final stream = client.monitorCpu();

  // 監視されなくなったときに自動でリソースを解放
  ref.onDispose(() {
    client.stopMonitoring();
  });

  return stream;
}
```

**使い方:**
```dart
final cpu = ref.watch(cpuUsageProvider(server));

cpu.when(
  data: (usage) => CpuChart(usage),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 4. Family Provider (パラメータ付き)

パラメータを受け取る Provider です。

```dart
@riverpod
Future<List<Container>> containers(ContainersRef ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return await client.listContainers();
}
```

**使い方:**
```dart
final containers = ref.watch(containersProvider(server));

// サーバーが異なれば、キャッシュされる状態も異なります
final containers2 = ref.watch(containersProvider(server2));
```

## パフォーマンスの最適化

- **Provider Keep-Alive**: リスナーがいなくなっても破棄されないようにするには `@Riverpod(keepAlive: true)` を使用します。
- **選択的な監視**: `select` を使用して、状態の特定の断片のみを監視します。
- **Provider キャッシュ**: Family Provider はパラメータごとに結果をキャッシュします。

## ベストプラクティス

1. **Provider を近くに配置する**: 利用する Widget の近くに定義します。
2. **コード生成を利用する**: 常に `@riverpod` を使用します。
3. **Provider の責務を絞る**: 単一責任の原則に従います。
4. **ロード状態を適切に扱う**: AsyncValue の各状態を必ずハンドルします。
5. **リソースを解放する**: クリーンアップには `ref.onDispose()` を使用します。
6. **深い Provider ツリーを避ける**: Provider のグラフ構造はフラットに保ちます。
