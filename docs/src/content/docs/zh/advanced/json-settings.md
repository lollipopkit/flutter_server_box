---
title: 隐藏设置（JSON）
description: 通过 JSON 编辑器访问高级设置
---

部分高级设置没有单独的 UI 控件，但可以通过 JSON 编辑器修改。

## 打开 JSON 编辑器

长按侧边栏中的 **设置**，即可打开 JSON 编辑器。

## 常用设置

### `timeOut`

连接超时时间，单位为秒。

```json
{"timeOut": 10}
```

**类型：** 整数　**默认值：** `5`

该值按 JSON 保存，连接代码会将其作为秒数使用，请设置为合理的正数。

### `recordHistory`

是否保存历史记录，例如 SFTP 路径。

```json
{"recordHistory": true}
```

**类型：** 布尔值　**默认值：** `true`

### `textFactor`

界面文字缩放系数。

```json
{"textFactor": 1.2}
```

**类型：** 数字　**默认值：** `1.0`

极端值可能导致部分界面无法正常使用。

## 查找其他设置

所有设置都定义在 [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart) 中。

查找类似以下代码的定义：

```dart
late final settingName = propertyDefault('settingKey', defaultValue);
```

设置 key 和默认值以代码为准；修改前请确认当前版本仍包含该设置。

## 修改前须知

- **先创建备份。** 错误的设置可能导致 App 无法启动。
- **保持 JSON 有效。** 注意引号、逗号、括号和数据类型。
- **一次只修改一项。** 修改后先重启或使用相关功能确认结果，再继续修改。
- **不要写入凭据。** 密码、token 和 private key 不应通过 JSON 编辑器添加到设置中。

## 恢复方法

如果修改后 App 无法启动：

1. 优先从修改前的备份恢复。
2. Android：在系统设置中清除 Server Box 的应用数据。
3. iOS：删除并重新安装 App。
4. 重新打开 App 后，再导入备份。

清除应用数据或重新安装会删除本机未备份的数据，请仅在其他方式无效时使用。
