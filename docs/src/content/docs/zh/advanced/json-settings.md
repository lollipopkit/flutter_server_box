---
title: 隐藏设置 (JSON)
description: 通过 JSON 编辑器访问高级设置
---

部分设置未在 UI 中提供，但可以通过 JSON 编辑器访问。

## 如何访问

长按侧边栏中的**“设置”**即可打开 JSON 编辑器。

## 常用隐藏设置

### timeOut

连接超时时间（秒）。

```json
{"timeOut": 10}
```

**类型：** 整数 | **默认值：** 5。该设置按 JSON 存储；连接代码会将它作为秒数
使用，请保持在合理范围内。

### recordHistory

保存历史记录（SFTP 路径等）。

```json
{"recordHistory": true}
```

**类型：** 布尔值 | **默认值：** true

### textFactor

文本缩放系数。

```json
{"textFactor": 1.2}
```

**类型：** 数字 | **默认值：** 1.0。该设置按 JSON 存储；极端值可能使界面无法使用。

## 查找更多设置

所有设置都定义在 [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart) 中。

查找类似以下代码的定义：
```dart
late final settingName = propertyDefault('settingKey', defaultValue);
```

## ⚠️ 重要提示

**在编辑之前：**
- **创建备份**：错误的设置可能导致应用无法打开
- **谨慎编辑**：JSON 必须保持有效
- **一次只修改一项设置**：每次修改后先测试

## 恢复方法

如果编辑后应用无法打开：
1. 清除应用数据（最后手段）
2. 重新安装应用
3. 从备份恢复
