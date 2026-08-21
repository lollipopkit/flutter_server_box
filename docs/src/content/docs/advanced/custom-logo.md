---
title: Custom Server Logo
description: Use custom images for server cards
---

Display custom logos on server cards using image URLs.

## Setup

1. Server settings → Custom Logo
2. Enter image URL

## URL Placeholders

### {DIST} - Linux Distribution

Replaced automatically with the detected distribution:

```text
https://example.com/{DIST}.png
```

The requested file can be `debian.png`, `ubuntu.png`, `arch.png`, and so on. If
the system is not recognized, `{DIST}` is left unchanged; provide a generic URL
or avoid this placeholder when a fallback is needed.

### {BRIGHT} - Theme

Replaced automatically with the current theme:

```text
https://example.com/{BRIGHT}.png
```

The requested file is `light.png` or `dark.png`.

### Combining Both Placeholders

```text
https://example.com/{DIST}-{BRIGHT}.png
```

The requested file can be `debian-light.png`, `ubuntu-dark.png`, and so on.

## Tips

- Use PNG or SVG images
- Recommended size: 64x64 to 128x128 pixels
- Use HTTPS URLs
- Keep image files small

## Supported Distributions

debian, ubuntu, centos, fedora, opensuse, kali, alpine, arch, rocky, deepin, armbian, wrt, coreelec

Full list: [`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart)
