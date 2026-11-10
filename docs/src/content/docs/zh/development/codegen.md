---
title: 代码生成
description: 生成 Dart、Flutter 本地化及 Rust 绑定代码
---

本项目使用代码生成工具构建不可变模型（Immutable Models）、JSON 序列化方法、Riverpod Provider、多语言本地化代码以及 Rust FFI 绑定。修改对应源码后，请运行相应的生成命令。

## 何时运行代码生成

修改以下任意源文件后，均需重新运行代码生成：

- 带有 `@freezed` 注解的数据模型
- 带有 `@JsonSerializable` 注解的类
- 带有 `@riverpod` 注解的 Provider
- `lib/l10n/*.arb` 多语言资源文件
- `crates/sbm_ffi/src/api` 下的 Rust 接口定义

## Dart 代码生成

### 常规构建

```bash
dart run build_runner build
```

### 清理缓存后重建

当缓存的资源依赖图（Asset Graph）与源码树不一致时（例如合并分支引入了新的生成文件后），过期的 `.dart_tool/build/asset_graph.json` 可能导致 `build_runner` 卡死且不输出有效报错。此时请先清理缓存再重新生成：

```bash
dart run build_runner clean
dart run build_runner build
```

## 生成产物说明

### Freezed（`*.freezed.dart`）

Freezed 用于生成不可变模型实现、`copyWith` 方法、相等性比较以及联合类型（Union Types）接口：

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### JSON 序列化（`*.g.dart`）

`json_serializable` 根据类字段自动生成 `fromJson` 与 `toJson` 方法：

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

### Riverpod Provider（`*.g.dart`）

`riverpod_generator` 根据带有 `@riverpod` 注解的类自动生成 Provider 定义：

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### Hive 旧版数据读取器

当前项目不再使用生成器创建 Hive Adapter，模型类上也已移除 Hive 注解。`lib/hive/` 目录下的读取器（`legacy_adapters.dart`、`frozen_adapters.dart`、`spi_legacy_adapter.dart`）均为手写且冻结的兼容层，仅用于读取历史发布版本写入的二进制数据以完成 SQLite 迁移。由于旧版本数据库不包含后续新增字段，切勿根据最新模型结构重新生成这些读取器；仅在确需修复旧版本数据升级兼容问题时才可修改，并需同步更新对应的迁移单元测试。

## Rust 绑定（`flutter_rust_bridge`）

修改 `crates/sbm_ffi/src/api` 下的 Rust 接口后，运行以下命令重新生成 Dart 绑定：

```bash
flutter_rust_bridge_codegen generate
```

生成器会读取 `flutter_rust_bridge.yaml` 并将绑定代码写入 `lib/src/rust/`。请勿手动编辑生成的文件，也不要运行 `flutter_rust_bridge_codegen integrate`（其默认脚手架模板不适用于本仓库结构）。

## 多语言本地化代码

编辑 `lib/l10n/*.arb` 中的多语言文案后，运行：

```bash
flutter gen-l10n
```

生成的本地化 Dart 代码位于 `lib/generated/l10n/`。

## 注意事项

- `build_runner` 2.15 已废弃 `--delete-conflicting-outputs` 参数（传入只会打印警告且不生效），遇到缓存冲突时请使用 `dart run build_runner clean`。
- 受 Git 跟踪的生成文件需随源码变更一并提交。
- 请勿手动编辑 `*.g.dart`、`*.freezed.dart` 或 `lib/generated/` 下的生成产物。
- 修改模型定义后，请先完成代码生成，再执行静态分析（`flutter analyze`）与单元测试。
