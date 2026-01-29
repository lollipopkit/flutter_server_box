---
title: 自定义服务器 Logo
description: 为服务器卡片使用自定义图标
---

通过图片 URL 在服务器卡片上显示自定义 Logo。

## 设置步骤

1. 服务器设置 → 自定义 Logo
2. 输入图片 URL

## URL 占位符

### {DIST} - Linux 发行版

自动替换为检测到的发行版：

```
https://example.com/{DIST}.png
```

将变为：`debian.png`, `ubuntu.png`, `arch.png` 等。

### {BRIGHT} - 主题

自动替换为当前主题：

```
https://example.com/{BRIGHT}.png
```

将变为：`light.png` 或 `dark.png`。

### 组合使用

```
https://example.com/{DIST}-{BRIGHT}.png
```

将变为：`debian-light.png`, `ubuntu-dark.png` 等。

## 提示

- 使用 PNG 或 SVG 格式
- 建议尺寸：64x64 到 128x128 像素
- 使用 HTTPS URL
- 保持文件体积较小

## 支持的发行版

debian, ubuntu, centos, fedora, opensuse, kali, alpine, arch, rocky, deepin, armbian, wrt

完整列表：[`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart)
