---
title: 代码生成
description: 使用代码生成工具生成 Dart、Flutter 和 Rust 绑定代码
---

Server Box 使用代码生成处理 immutable model、JSON 序列化、Riverpod provider、旧版 Hive adapter、本地化代码和 Rust bindings。

## 什么时候运行代码生成

修改以下内容后，请运行对应的生成器：

- 带 `@freezed` 注解的 model
- 带 `@JsonSerializable` 注解的 class
- 当前生成 adapter 列表中的 Hive model
- 带 `@riverpod` 注解的 provider
- ARB 本地化文件
- `crates/sbm_ffi/src/api` 下的 Rust API

`lib/hive/legacy_adapters.dart` 中冻结的旧版 adapter 不属于生成列表。它们用于读取旧版本写入的 box，不要根据当前 model 重新生成。

## Dart 代码生成

### 常规生成

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 清理后重新生成

仅当生成缓存异常或结果不一致时使用：

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

## 生成文件

### Freezed（`*.freezed.dart`）

Freezed 生成 immutable model、`copyWith`、相等性比较和 union API：

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### JSON 序列化（`*.g.dart`）

`json_serializable` 根据 model 的字段生成 `fromJson` 和 `toJson`：

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

### Riverpod provider（`*.g.dart`）

`riverpod_generator` 根据 `@riverpod` 声明生成 provider：

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### Hive adapter（`*.g.dart`）

生成的 Hive adapter 只覆盖当前仍在生成列表中的 model：

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```

`lib/hive/legacy_adapters.dart` 中的 adapter 是有意冻结的读取器。不要把新增字段的当前 model 加入旧版 adapter 的生成列表：旧版本写入的 box 没有这些字段，新增的 non-nullable 字段甚至可能导致 box 无法打开。只有在已发布版本实际写入的数据格式发生变化，并且迁移测试同步更新时，才修改冻结读取器。

## Rust bindings（flutter_rust_bridge）

修改 `crates/sbm_ffi/src/api` 后，重新生成 Dart bindings：

```bash
flutter_rust_bridge_codegen generate
```

配置文件是 `flutter_rust_bridge.yaml`，生成结果位于 `lib/src/rust/`。这些文件由工具维护，请勿手动编辑。不要运行 `flutter_rust_bridge_codegen integrate`；该命令会生成不适用于本仓库的模板结构。

## 本地化代码

修改 `lib/l10n/*.arb` 后运行：

```bash
flutter gen-l10n
```

生成代码位于 `lib/generated/l10n/`。

## 注意事项

- 使用 `--delete-conflicting-outputs` 处理生成文件冲突。
- 生成文件已纳入版本控制时，请将生成结果一并提交。
- 不要手动编辑 `*.g.dart`、`*.freezed.dart` 或 `lib/generated/` 下的文件。
- 修改 model 后，先完成代码生成，再运行 analyze 和测试。
