---
title: Custom Server Logo
description: Set a custom icon for a server card
---

You can set a custom logo for a server card with an image URL.

## Setup

1. Open the server edit page and go to **More → Logo URL**.
2. Enter the image URL and save.

## URL placeholders

### `{DIST}`: Linux distribution

`{DIST}` is replaced with the Linux distribution detected by the App:

```text
https://example.com/{DIST}.png
```

For example, the App may request `debian.png`, `ubuntu.png`, or `arch.png`. If it cannot identify the distribution, `{DIST}` remains unchanged. For a generic icon, provide a URL without this placeholder or provide a matching fallback file on the server.

### `{BRIGHT}`: Theme

`{BRIGHT}` is replaced with the current theme:

```text
https://example.com/{BRIGHT}.png
```

The requested file is `light.png` or `dark.png`.

### Combining both

```text
https://example.com/{DIST}-{BRIGHT}.png
```

For example, the requested file may be `debian-light.png` or `ubuntu-dark.png`.

## Recommendations

- Use PNG or SVG.
- Recommended size: 64×64 to 128×128 pixels.
- Prefer HTTPS URLs.
- Keep image files small to avoid slowing down card rendering.

## Supported distributions

debian, ubuntu, centos, fedora, opensuse, kali, alpine, arch, rocky, deepin, armbian, wrt, coreelec

See [`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart) for the complete list.
