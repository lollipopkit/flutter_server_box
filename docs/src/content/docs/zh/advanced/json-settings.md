---
title: 隐藏设置 (JSON)
description: 通过 JSON 编辑器访问高级设置
---

有些设置在 UI 中是隐藏的，但可以通过 JSON 编辑器进行访问。

## 如何访问

长按侧边栏中的**“设置”**即可打开 JSON 编辑器。

## 常用隐藏设置

### timeOut

连接超时时间（秒）。

```json
{"timeOut": 10}
```

**类型：** 整数 | **默认值：** 5 | **范围：** 1-60

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

**类型：** 浮点数 | **默认值：** 1.0 | **范围：** 0.8-1.5

## 查找更多设置

所有设置都定义在 [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart) 中。

查找如下代码：
```dart
late final settingName = StoreProperty(box, 'settingKey', defaultValue);
```

## ⚠️ 重要提示

**在编辑之前：**
- **创建备份** - 错误的设置可能导致应用无法打开
- **谨慎编辑** - JSON 必须有效

## 恢复方法

如果编辑后应用无法打开：
1. 清除应用数据（最后手段）
2. 重新安装应用
3. 从备份恢复
