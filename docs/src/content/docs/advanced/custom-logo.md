---
title: Custom Server Logo
description: Set the large image shown at the top of a server's detail page
---

Set a custom image for the top of a server's detail page. This is separate
from **Mark URL**, which sets the small mark shown beside a server's name in
lists.

## Per-server setting

1. Open the server's edit page and expand **Optional → Appearance & location**.
2. Enter the image URL in **Logo URL** and save the server.

The per-server Logo URL takes precedence over the global setting. Per-server
Logo URLs do not support formatting placeholders.

## Global default

Open **Settings → Server → General → Distribution mark → Logo URL** to set the
default image URL for servers without their own Logo URL. Only the global Logo
URL supports the formatting placeholders below.

## URL placeholders

### `{DIST}`: Linux distribution

`{DIST}` is replaced with the Linux distribution name detected by the App:

```text
https://example.com/{DIST}.png
```

For example, the resulting URL may end in `debian.png`, `ubuntu.png`, or
`arch.png`. The App substitutes this placeholder only in the global Logo URL.
If it cannot detect the distribution, the global Logo is not used.

### `{BRIGHT}`: Theme

`{BRIGHT}` is replaced according to the current theme:

```text
https://example.com/{BRIGHT}.png
```

The global Logo URL resolves to `light.png` in a light theme and `dark.png` in
a dark theme.

### Combining both

```text
https://example.com/{DIST}-{BRIGHT}.png
```

For example, the App may request `debian-light.png` or `ubuntu-dark.png`,
depending on the detected distribution and current theme.

## Recommendations

- Use a PNG or SVG image between 64×64 and 128×128 pixels.
- Prefer an HTTPS URL.
- Keep the image small so loading it does not slow down the server card.

## Supported distributions

debian, ubuntu, centos, fedora, opensuse, kali, alpine, arch, rocky, deepin, armbian, wrt, coreelec

See [`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart) for the complete list.
