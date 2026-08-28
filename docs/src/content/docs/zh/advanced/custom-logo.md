---
title: 自定义服务器 Logo
description: 为服务器卡片设置自定义图标
---

你可以使用图片 URL，为服务器卡片设置自定义 Logo。

## 设置步骤

1. 打开服务器编辑页，进入 **更多 → Logo URL**。
2. 输入图片 URL 并保存。

## URL 占位符

### `{DIST}`：Linux 发行版

`{DIST}` 会替换为 App 检测到的 Linux 发行版名称：

```text
https://example.com/{DIST}.png
```

例如，App 会请求 `debian.png`、`ubuntu.png` 或 `arch.png`。如果无法识别发行版，`{DIST}` 会保持不变。需要通用图标时，请提供不使用该占位符的 URL，或在服务器端提供未替换名称对应的文件。

### `{BRIGHT}`：主题

`{BRIGHT}` 会替换为当前主题：

```text
https://example.com/{BRIGHT}.png
```

实际请求的文件名为 `light.png` 或 `dark.png`。

### 组合使用

```text
https://example.com/{DIST}-{BRIGHT}.png
```

例如，实际请求的文件名可能是 `debian-light.png` 或 `ubuntu-dark.png`。

## 建议

- 使用 PNG 或 SVG 格式。
- 建议尺寸为 64×64 至 128×128 像素。
- 优先使用 HTTPS URL。
- 控制图片文件大小，避免影响加载速度。

## 支持的发行版

debian、ubuntu、centos、fedora、opensuse、kali、alpine、arch、rocky、deepin、armbian、wrt、coreelec

完整列表请参阅 [`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart)。
