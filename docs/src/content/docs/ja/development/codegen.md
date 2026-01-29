---
title: コード生成
description: build_runner を使用したコード生成
---

Server Box では、モデル、状態管理、シリアライズのためにコード生成を多用しています。

## コード生成を実行するタイミング

以下のファイルを変更した後に実行してください。

- `@freezed` アノテーションが付いたモデル
- `@JsonSerializable` が付いたクラス
- Hive モデル
- `@riverpod` が付いた Provider
- ローカライズファイル (ARB ファイル)

## コード生成の実行

```bash
# すべてのコードを生成
dart run build_runner build --delete-conflicting-outputs

# クリーンアップして再生成
dart run build_runner build --delete-conflicting-outputs --clean
```

## 生成されるファイル

### Freezed (`*.freezed.dart`)

Union 型を持つ不変データモデル:

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### JSON シリアライズ (`*.g.dart`)

`json_serializable` によって生成されます:

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

`@riverpod` アノテーションから生成されます:

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### Hive アダプター (`*.g.dart`)

Hive モデル (hive_ce) 用に自動生成されます:

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```

## ローカライズの生成

```bash
flutter gen-l10n
```

`lib/l10n/*.arb` ファイルから `lib/generated/l10n/` を生成します。

## ヒント

- 競合を避けるために `--delete-conflicting-outputs` を使用してください。
- 生成されたファイルを `.gitignore` に追加してください。
- 生成されたファイルを手動で編集しないでください。
