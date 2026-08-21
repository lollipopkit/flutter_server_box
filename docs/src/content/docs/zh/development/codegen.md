---
title: 代码生成
description: 使用 build_runner 进行代码生成
---

Server Box 广泛使用代码生成来处理模型、状态管理和序列化。

## 何时运行代码生成

修改以下内容后，需要运行相应的生成器：

- 带有 `@freezed` 注解的模型
- 带有 `@JsonSerializable` 的类
- Hive 模型
- 带有 `@riverpod` 的 Provider
- 本地化文件（ARB 文件）

## 运行代码生成

### 普通构建

用于常规代码生成：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 清理后重建

仅在生成缓存异常或生成结果不一致时使用。先清理，再重新生成：

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

## 生成的文件类型

### Freezed (`*.freezed.dart`)

包含联合类型（Union types）的不可变数据模型：

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### JSON 序列化 (`*.g.dart`)

由 `json_serializable` 生成：

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

由 `@riverpod` 注解生成：

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### 旧版 Hive 适配器（`*.g.dart`）

为旧版存储迁移保留的 Hive 适配器：

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```


## Rust 绑定 (flutter_rust_bridge)

修改 `crates/sbm_ffi/src/api` 后,重新生成 Dart 绑定：

```bash
flutter_rust_bridge_codegen generate
```

配置位于 `flutter_rust_bridge.yaml`;输出到 `lib/src/rust/`(生成文件勿手改)。

## 生成本地化代码

```bash
flutter gen-l10n
```

根据 `lib/l10n/*.arb` 文件生成 `lib/generated/l10n/` 目录下的代码。

## 提示

- 使用 `--delete-conflicting-outputs` 避免冲突
- 如果生成文件已被本仓库纳入版本控制，请将其提交
- **切勿**手动编辑生成的文件
