---
title: Custom Logo
description: Use custom logos for your servers
---

You can customize the logo displayed on server cards by setting a custom image URL.

## Setting Up Custom Logo

1. Open server settings
2. Find the **Custom Logo** option
3. Enter the URL of your image

## URL Placeholders

The logo URL supports special placeholders that are automatically replaced:

### {DIST} - Linux Distribution

Automatically replaced with the detected Linux distribution name.

**Example:**
```
https://example.com/{DIST}.png
```

**Becomes:**
```
https://example.com/debian.png
https://example.com/ubuntu.png
https://example.com/arch.png
```

**Supported distributions:**
- debian
- ubuntu
- centos
- fedora
- opensuse
- kali
- wrt
- armbian
- arch
- alpine
- rocky
- deepin

For the complete list, see [`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart) in the source code.

### {BRIGHT} - Theme Brightness

Automatically replaced with the current theme brightness.

**Example:**
```
https://example.com/{BRIGHT}.png
```

**Becomes:**
```
https://example.com/light.png  (light theme)
https://example.com/dark.png   (dark theme)
```

## Combining Placeholders

You can use multiple placeholders in one URL:

```
https://example.com/{DIST}-{BRIGHT}.png
```

**Becomes:**
```
https://example.com/debian-light.png
https://example.com/ubuntu-dark.png
```

## Tips

- Use **PNG** or **SVG** formats for best quality
- Recommended size: 64x64 to 128x128 pixels
- Use **HTTPS** URLs for security
- Test URL in browser first to verify it works
- Keep file sizes small for faster loading

## Example Logo Services

### Static Logo Hosting

Host your own logos on a web server:

```nginx
# Nginx configuration
location /logos/ {
    root /var/www/;
    autoindex off;
}
```

### Dynamic Logo Generation

Use a service that generates logos on-demand:

```bash
# Simple logo server example
https://logos.example.com/{DIST}.png
```

## Troubleshooting

### Logo Not Showing

- Verify URL is accessible
- Check image format is supported
- Ensure network connectivity
- Try opening URL in browser

### Wrong Logo Displayed

- Check distribution detection worked
- Verify placeholder syntax
- Test URL with actual values
