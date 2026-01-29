---
title: Benutzerdefiniertes Server-Logo
description: Verwenden Sie benutzerdefinierte Bilder für Serverkarten
---

Zeigen Sie benutzerdefinierte Logos auf Serverkarten mithilfe von Bild-URLs an.

## Einrichtung

1. Servereinstellungen → Benutzerdefiniertes Logo
2. Bild-URL eingeben

## URL-Platzhalter

### {DIST} - Linux-Distribution

Wird automatisch durch die erkannte Distribution ersetzt:

```
https://example.com/{DIST}.png
```

Wird zu: `debian.png`, `ubuntu.png`, `arch.png`, usw.

### {BRIGHT} - Theme

Wird automatisch durch das aktuelle Theme ersetzt:

```
https://example.com/{BRIGHT}.png
```

Wird zu: `light.png` oder `dark.png`

### Beide kombinieren

```
https://example.com/{DIST}-{BRIGHT}.png
```

Wird zu: `debian-light.png`, `ubuntu-dark.png`, usw.

## Tipps

- Verwenden Sie PNG- oder SVG-Formate
- Empfohlene Größe: 64x64 bis 128x128 Pixel
- Verwenden Sie HTTPS-URLs
- Halten Sie die Dateigrößen gering

## Unterstützte Distributionen

debian, ubuntu, centos, fedora, opensuse, kali, alpine, arch, rocky, deepin, armbian, wrt

Vollständige Liste: [`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart)
