---
title: Compilación
description: Instrucciones de compilación para diferentes plataformas
---

Flutter Server Box utiliza un sistema de compilación personalizado (`fl_build`) para compilaciones multiplataforma.

## Requisitos Previos

- Flutter SDK (canal stable)
- Herramientas específicas de cada plataforma (Xcode para iOS, Android Studio para Android)
- Cadena de herramientas de Rust (para algunas dependencias nativas)

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
