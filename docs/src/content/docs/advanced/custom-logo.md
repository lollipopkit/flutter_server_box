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

Auto-replaced with detected distribution:

```
https://example.com/{DIST}.png
```

Becomes: `debian.png`, `ubuntu.png`, `arch.png`, etc.

### {BRIGHT} - Theme

Auto-replaced with current theme:

```
https://example.com/{BRIGHT}.png
```

Becomes: `light.png` or `dark.png`

### Combine Both

```
https://example.com/{DIST}-{BRIGHT}.png
```

Becomes: `debian-light.png`, `ubuntu-dark.png`, etc.

## Tips

- Use PNG or SVG formats
- Recommended size: 64x64 to 128x128 pixels
- Use HTTPS URLs
- Keep file sizes small

## Supported Distributions

debian, ubuntu, centos, fedora, opensuse, kali, alpine, arch, rocky, deepin, armbian, wrt

Full list: [`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart)
