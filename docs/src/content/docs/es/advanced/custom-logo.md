---
title: Logo de Servidor Personalizado
description: Usa imágenes personalizadas para las tarjetas de servidor
---

Muestra logos personalizados en las tarjetas de servidor mediante URLs de imagen.

## Configuración

1. Ajustes del servidor → Logo personalizado
2. Introduce la URL de la imagen

## Marcadores de posición de URL

### {DIST} - Distribución Linux

Se reemplaza automáticamente por la distribución detectada:

```
https://ejemplo.com/{DIST}.png
```

Se convierte en: `debian.png`, `ubuntu.png`, `arch.png`, etc.

### {BRIGHT} - Tema

Se reemplaza automáticamente por el tema actual:

```
https://ejemplo.com/{BRIGHT}.png
```

Se convierte en: `light.png` o `dark.png`

### Combinar ambos

```
https://ejemplo.com/{DIST}-{BRIGHT}.png
```

Se convierte en: `debian-light.png`, `ubuntu-dark.png`, etc.

## Consejos

- Usa formatos PNG o SVG
- Tamaño recomendado: de 64x64 a 128x128 píxeles
- Usa URLs HTTPS
- Mantén tamaños de archivo pequeños

## Distribuciones Soportadas

debian, ubuntu, centos, fedora, opensuse, kali, alpine, arch, rocky, deepin, armbian, wrt

Lista completa: [`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart)
