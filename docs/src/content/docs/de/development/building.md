---
title: Bauen
description: Bauanleitungen für verschiedene Plattformen
---

Server Box verwendet ein benutzerdefiniertes Build-System (`fl_build`) für plattformübergreifende Builds.

## Voraussetzungen

- Flutter SDK (stabiler Kanal)
- Plattformspezifische Tools (Xcode für iOS, Android Studio für Android)
- Rust-Toolchain (erforderlich: der Status-Parser ist ein Rust-Crate, das über flutter_rust_bridge/cargokit auf jeder Plattform in die App eingebaut wird)

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

## Den Monitor bauen

Der serverseitige Monitor ist eine eigene Binärdatei, gebaut aus `monitor/`. Er
ist nicht Teil eines App-Builds.

```bash
cd monitor

# Backend
cargo build --release

# Panel — vom Agent selbst ausgeliefert, wenn frontend/dist vorhanden ist
cd frontend && npm install && npm run build
```

`make monitor-dev` im Wurzelverzeichnis startet beides im Entwicklungsmodus: die
API auf `:3770` und den vite-Dev-Server des Panels auf `:3000`.

Release-Artefakte stammen aus dem Workflow `monitor-release.yml`, der nur per
`workflow_dispatch` läuft und `monitor-v*`-Tags getrennt von den Releases der
App veröffentlicht. Docker liegt in `monitor/Dockerfile`.

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
