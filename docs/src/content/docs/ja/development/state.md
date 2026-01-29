---
title: 状態管理
description: Riverpod ベースの状態管理パターン
---

Flutter Server Box は、状態管理のためにコード生成を伴う Riverpod を使用しています。

## Provider の種類

### StateProvider

読み書き可能な単純な状態:

```dart
@riverpod
class Settings extends _$Settings {
  @override
  SettingsModel build() {
    return SettingsModel.defaults();
  }

  void update(SettingsModel newSettings) {
    state = newSettings;
  }
}
```

### AsyncNotifierProvider

ロード中やエラー状態を伴う、非同期にロードされる状態:

```dart
@riverpod
class ServerStatus extends _$ServerStatus {
  @override
  Future<StatusModel> build(Server server) async {
    return fetchStatus(server);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => fetchStatus(server));
  }
}
```

### StreamProvider

ストリームからのリアルタイムデータ:

```dart
@riverpod
Stream<CpuUsage> cpuUsage(CpuUsageRef ref, Server server) {
  return cpuService.monitor(server);
}
```

## 状態パターン

### ロード状態

```dart
state.when(
  data: (data) => DataWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### Family Provider

パラメータを受け取る Provider:

```dart
@riverpod
List<Container> containers(ContainersRef ref, Server server) {
  return containerService.list(server);
}
```

### Auto-Dispose

参照されなくなったときに破棄される Provider:

```dart
@Riverpod(keepAlive: false)
class TempState extends _$TempState {
  // ...
}
```

## ベストプラクティス

1. **コード生成を使用する**: 常に `@riverpod` アノテーションを使用してください
2. **Provider を近くに配置する**: 利用するウィジェットの近くに定義してください
3. **シングルトンを避ける**: 代わりに Provider を使用してください
4. **適切に階層化する**: UI ロジックとビジネスロジックを分離してください

## ウィジェットでの状態の読み取り

```dart
class ServerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverStatusProvider(server));
    return status.when(...);
  }
}
```

## 状態の変更

```dart
ref.read(settingsProvider.notifier).update(newSettings);
```
