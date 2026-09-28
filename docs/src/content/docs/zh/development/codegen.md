---
title: 代码生成
description: 使用代码生成工具生成 Dart、Flutter 和 Rust 绑定代码
---

项目通过代码生成创建 immutable model 实现、JSON serializer、Riverpod provider、Hive adapter、本地化代码和 Rust bindings。修改源码后，请运行对应的生成器。

## 什么时候运行代码生成

修改以下输入后需要运行代码生成：

- 带 `@freezed` 注解的 model
- 带 `@JsonSerializable` 注解的 class
- 当前生成 adapter 列表中的 Hive model
- 带 `@riverpod` 注解的 provider
- ARB 本地化文件
- `crates/sbm_ffi/src/api` 下的 Rust API

`lib/hive/legacy_adapters.dart` 中冻结的 adapter 不在生成列表内。它们负责读取旧版本创建的 box，不要用当前 model 重新生成。

## Dart 代码生成

### 常规生成

```bash
dart run build_runner build
```

### 清理后重新生成

当缓存的 asset graph 与源码树不同步时，可先清理再生成，例如 merge 引入新的生成源文件后。`.dart_tool/build/asset_graph.json` 过期可能使 build_runner 在某个 phase 中途停滞，且没有给出有用的错误信息。

```bash
dart run build_runner clean
dart run build_runner build
```

## 生成文件

### Freezed（`*.freezed.dart`）

Freezed 会生成 immutable model 实现、`copyWith`、相等性比较和 union API：

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### JSON 序列化（`*.g.dart`）

`json_serializable` 会根据 model 字段生成 `fromJson` 和 `toJson` 方法：

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

`riverpod_generator` 根据带有 `@riverpod` 的 class 生成 provider：

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### Hive adapter（`*.g.dart`）

Hive adapter 生成器只处理当前生成列表中的 model：

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```

`lib/hive/legacy_adapters.dart` 中的 adapter 是冻结的读取器。不要重新生成它们，也不要把含新增字段的 model 加入旧版生成列表：旧 box 中没有这些字段，新增 non-nullable 字段可能导致旧 box 无法读取。只有已发布版本写入的数据确实需要兼容时才修改冻结读取器，并同步更新迁移测试。

## Rust bindings（flutter_rust_bridge）

修改 `crates/sbm_ffi/src/api` 下的 Rust API 后，重新生成 Dart bindings：

```bash
flutter_rust_bridge_codegen generate
```

生成器读取 `flutter_rust_bridge.yaml`，并将文件写入 `lib/src/rust/`。这些文件由工具维护，不要手动编辑。不要运行 `flutter_rust_bridge_codegen integrate`，因为它生成的模板结构不适用于本仓库。

## 本地化代码

编辑 `lib/l10n/*.arb` 中的本地化文件后，运行：

```bash
flutter gen-l10n
```

生成的本地化代码位于 `lib/generated/l10n/`。

## 注意事项

- build_runner 2.15 已移除 `--delete-conflicting-outputs`；现在传入只会显示 warning，不会产生作用。缓存异常时按上文清理。
- 仓库跟踪的生成文件需要随代码变更一并更新。
- 不要手动修改 `*.g.dart`、`*.freezed.dart` 或 `lib/generated/` 下的文件。
- 修改 model 后先完成代码生成，再运行 analyze 和测试。
