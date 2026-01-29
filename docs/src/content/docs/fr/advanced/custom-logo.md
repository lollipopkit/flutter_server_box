---
title: Logo de serveur personnalisé
description: Utiliser des images personnalisées pour les cartes de serveur
---

Affichez des logos personnalisés sur les cartes de serveur à l'aide d'URL d'images.

## Configuration

1. Paramètres du serveur → Logo personnalisé
2. Entrez l'URL de l'image

## Espaces réservés d'URL

### {DIST} - Distribution Linux

Remplacé automatiquement par la distribution détectée :

```
https://example.com/{DIST}.png
```

Devient : `debian.png`, `ubuntu.png`, `arch.png`, etc.

### {BRIGHT} - Thème

Remplacé automatiquement par le thème actuel :

```
https://example.com/{BRIGHT}.png
```

Devient : `light.png` ou `dark.png`

### Combiner les deux

```
https://example.com/{DIST}-{BRIGHT}.png
```

Devient : `debian-light.png`, `ubuntu-dark.png`, etc.

## Conseils

- Utilisez les formats PNG ou SVG
- Taille recommandée : 64x64 à 128x128 pixels
- Utilisez des URL HTTPS
- Gardez des tailles de fichiers réduites

## Distributions supportées

debian, ubuntu, centos, fedora, opensuse, kali, alpine, arch, rocky, deepin, armbian, wrt

Liste complète : [`dist.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/model/server/dist.dart)
