---
title: 隐藏设置（JSON）
description: 通过 JSON 编辑器访问高级设置
---

部分高级设置没有对应的界面控件，可以通过 JSON 编辑器修改。只有在了解设置用途后再更改数值。

## 打开 JSON 编辑器

打开 **设置 → 应用 → 通用 → 更多**，然后选择 **(Dev) Edit raw json**。

## 常用设置

### `timeOut`

连接最多等待的时间，单位为秒。

```json
{"timeOut": 10}
```

**类型：** 整数　**默认值：** `5`

连接逻辑会将该整数按秒解释。请根据网络状况设置为正数。

### `recordHistory`

是否保存最近使用的信息，例如 SFTP 路径。

```json
{"recordHistory": true}
```

**类型：** 布尔值　**默认值：** `true`

### `textFactor`

界面文字的缩放比例。

```json
{"textFactor": 1.2}
```

**类型：** 数字　**默认值：** `1.0`

极端值可能导致部分界面无法正常使用。

## 查找其他设置

设置 key 和默认值定义在 [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart) 中。

查找形式类似下面的声明：

```dart
late final settingName = propertyDefault('settingKey', defaultValue);
```

请以当前 App 版本对应源码中的 key 和默认值为准。设置可能随版本变化，修改前要确认该 key 仍然存在。

## 修改前须知

- **先备份数据。** JSON 格式错误或设置值不受支持，都可能导致 App 无法启动。
- **确保内容是有效 JSON。** 检查引号、逗号、括号和字段所需的数据类型。
- **每次只修改一个 key。** 重新打开 App 并检查相关功能，再继续修改其他值。
- **不要在此处填写凭据。** 不要通过设置 JSON 添加密码、token 或 private key。

## 恢复方法

如果修改后 App 无法启动，请按顺序尝试以下恢复方式：

1. 优先从修改前的备份恢复。
2. Android：在系统设置中清除 Server Box 的应用数据。
3. iOS：删除并重新安装 App。
4. 重新打开 App 后，再导入备份。

清除应用数据或重新安装会删除所有尚未备份的数据。只有其他恢复方式都不可用时才使用这些操作。
