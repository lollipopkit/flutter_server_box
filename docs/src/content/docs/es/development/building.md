---
title: Compilación
description: Instrucciones de compilación para diferentes plataformas
---

Server Box utiliza un sistema de compilación personalizado (`fl_build`) para compilaciones multiplataforma.

## Requisitos Previos

- Flutter SDK (canal stable)
- Herramientas específicas de cada plataforma (Xcode para iOS, Android Studio para Android)
- Cadena de herramientas de Rust (requerida: el parser de estado es un crate de Rust integrado en la app vía flutter_rust_bridge/cargokit en todas las plataformas)

## Compilación de Desarrollo

```bash
# Ejecutar en modo desarrollo
flutter run

# Ejecutar en un dispositivo específico
flutter run -d <id-del-dispositivo>
```

## Compilación de Producción

El proyecto utiliza `fl_build` para compilar:

```bash
# Compilar para una plataforma específica
dart run fl_build -p <plataforma>

# Plataformas disponibles:
# - ios
# - android
# - macos
# - linux
# - windows
```

## Compilaciones Específicas por Plataforma

### iOS

```bash
dart run fl_build -p ios
```

Requiere:
- macOS con Xcode
- CocoaPods
- Cuenta de Apple Developer para la firma

### Android

```bash
dart run fl_build -p android
```

Requiere:
- Android SDK
- Java Development Kit
- Keystore para la firma

### macOS

```bash
dart run fl_build -p macos
```

### Linux

```bash
dart run fl_build -p linux
```

### Windows

```bash
dart run fl_build -p windows
```

Requiere Windows con Visual Studio.

## Compilar el monitor

El monitor del lado del servidor es un binario aparte, compilado desde
`monitor/`. No forma parte de ninguna compilación de la app.

```bash
cd monitor

# Backend
cargo build --release

# Panel — servido por el propio agente cuando existe frontend/dist
cd frontend && npm install && npm run build
```

`make monitor-dev` desde la raíz del repositorio arranca ambos en modo
desarrollo: la API en `:3770` y el servidor de desarrollo vite del panel en
`:3000`.

Los artefactos de release salen del workflow `monitor-release.yml`, que solo se
ejecuta por `workflow_dispatch` y publica tags `monitor-v*` separados de las
releases de la app. Docker está en `monitor/Dockerfile`.

## Pre/Post Compilación

El script `make.dart` se encarga de:

- Generación de metadatos
- Actualización de cadenas de versión
- Configuraciones específicas de plataforma

## Solución de Problemas

### Compilación Limpia

```bash
flutter clean
dart run build_runner build --delete-conflicting-outputs
flutter pub get
```

### Discrepancia de Versión

Asegúrate de que todas las dependencias son compatibles:
```bash
flutter pub upgrade
```

## Lista de Verificación de Lanzamiento

1. Actualizar la versión en `pubspec.yaml`
2. Ejecutar la generación de código
3. Ejecutar las pruebas
4. Compilar para todas las plataformas de destino
5. Probar en dispositivos físicos
6. Crear lanzamiento (release) en GitHub
