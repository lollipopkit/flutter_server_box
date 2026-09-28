---
title: 自定义服务器 Logo
description: 设置显示在服务器详情页顶部的大图
---

自定义 Logo 会显示在服务器详情页顶部。此项与 **标识地址（Mark URL）** 不同；后者用于设置
服务器列表中名称旁的小标识。

## 单台服务器设置

1. 打开服务器编辑页，展开 **可选 → 外观与位置**。
2. 在 **Logo 地址** 中输入图片 URL，并保存服务器配置。

单台服务器设置的优先级高于全局设置。单台服务器的 Logo URL 不支持格式化占位符。

## 全局默认设置

打开 **设置 → 服务器 → 通用 → 发行版标识 → Logo 地址**，设置所有未单独配置 Logo 的服务器使用的默认图片 URL。
只有全局 Logo 地址支持下文的格式化占位符。

## URL 占位符

### `{DIST}`：Linux 发行版

`{DIST}` 会替换为 App 检测到的 Linux 发行版名称：

```text
https://example.com/{DIST}.png
```

例如，最终 URL 可能以 `debian.png`、`ubuntu.png` 或 `arch.png` 结尾。仅当全局 Logo 地址使用此占位符时，
App 才会根据检测到的发行版替换它；如果无法检测发行版，则不会使用该全局 Logo。

### `{BRIGHT}`：主题

`{BRIGHT}` 会根据当前主题替换：

```text
https://example.com/{BRIGHT}.png
```

全局 Logo 地址会在浅色主题下使用 `light.png`，在深色主题下使用 `dark.png`。

### 组合使用

```text
https://example.com/{DIST}-{BRIGHT}.png
```

例如，App 可能请求 `debian-light.png` 或 `ubuntu-dark.png`，具体取决于检测到的发行版和当前主题。

## 建议

- 使用 64×64 至 128×128 像素的 PNG 或 SVG 图片。
- 优先使用 HTTPS URL。
- 控制图片大小，避免拖慢服务器卡片的加载。

## 支持的发行版

debian、ubuntu、centos、fedora、opensuse、kali、alpine、arch、rocky、deepin、armbian、wrt、coreelec

完整列表请参阅 [`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart)。
