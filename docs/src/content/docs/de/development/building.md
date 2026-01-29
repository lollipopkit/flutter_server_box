---
title: Bauen
description: Bauanleitungen für verschiedene Plattformen
---

Flutter Server Box verwendet ein benutzerdefiniertes Build-System (`fl_build`) für plattformübergreifende Builds.

## Voraussetzungen

- Flutter SDK (stabiler Kanal)
- Plattformspezifische Tools (Xcode für iOS, Android Studio für Android)
- Rust-Toolchain (für einige native Abhängigkeiten)

## Entwicklungs-Build

```bash
# Im Entwicklungsmodus ausführen
flutter run

# Auf einem bestimmten Gerät ausführen
flutter run -d <device-id>
```

## Produktions-Build

Das Projekt verwendet `fl_build` zum Bauen:

```bash
# Für eine bestimmte Plattform bauen
dart run fl_build -p <platform>

# Verfügbare Plattformen:
# - ios
# - android
# - macos
# - linux
# - windows
```

## Plattformspezifische Builds

### iOS

```bash
dart run fl_build -p ios
```

Erfordert:
- macOS mit Xcode
- CocoaPods
- Apple Developer Account für die Signierung

### Android

```bash
dart run fl_build -p android
```

Erfordert:
- Android SDK
- Java Development Kit
- Keystore für die Signierung

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

Erfordert Windows mit Visual Studio.

## Vor/Nach dem Build

Das Skript `make.dart` übernimmt:

- Metadaten-Generierung
- Aktualisierung der Versions-Strings
- Plattformspezifische Konfigurationen

## Fehlerbehebung

### Clean Build

```bash
flutter clean
dart run build_runner build --delete-conflicting-outputs
flutter pub get
```

### Versions-Konflikt

Stellen Sie sicher, dass alle Abhängigkeiten kompatibel sind:
```bash
flutter pub upgrade
```

## Release-Checkliste

1. Version in `pubspec.yaml` aktualisieren
2. Codegenerierung ausführen
3. Tests ausführen
4. Für alle Zielplattformen bauen
5. Auf physischen Geräten testen
6. GitHub-Release erstellen
