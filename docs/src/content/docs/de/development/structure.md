---
title: Projektstruktur
description: Verständnis der Server Box Codebasis
---

Das Server Box-Projekt folgt einer modularen Architektur mit einer klaren Trennung der Belange.

## Monorepo-Layout

```
flutter_server_box/
├── lib/               # Flutter-App (siehe unten)
├── crates/
│   ├── sbm_parser/    # Gemeinsamer Status-Parser (Single Source of Truth,
│   │                  # App via FFI, Monitor als direkte Abhängigkeit)
│   └── sbm_ffi/       # flutter_rust_bridge-Binding-Crate + cargokit
│                      # Flutter-Plugin-Hülle (ein Verzeichnis)
├── monitor/           # Serverseitiger Monitor (Rust-Dienst + React-Frontend)
├── packages/          # Eingebundene Dart-Forks (Pfad-Abhängigkeiten)
├── docs/              # Diese Dokumentationsseite (Astro Starlight)
├── website/           # Projekt-Website
└── Cargo.toml         # Rust-Workspace-Wurzel
```

## App-Verzeichnisstruktur

```
lib/
├── core/              # Kern-Dienstprogramme und Erweiterungen
├── data/              # Datenschicht
│   ├── model/         # Datenmodelle nach Funktionen
│   ├── provider/      # Riverpod Provider
│   └── store/         # Lokale Speicherung (Hive)
├── view/              # UI-Schicht
│   ├── page/          # Hauptseiten
│   └── widget/        # Wiederverwendbare Widgets
├── generated/         # Generierte Lokalisierung
├── l10n/              # Lokalisierungs-ARB-Dateien
└── hive/              # Hive-Adapter
```

## Kernschicht (`lib/core/`)

Enthält Dienstprogramme, Erweiterungen und Routing-Konfiguration:

- **Erweiterungen**: Dart-Erweiterungen für gängige Typen
- **Routen**: App-Routing-Konfiguration
- **Dienstprogramme**: Gemeinsame Hilfsfunktionen

## Datenschicht (`lib/data/`)

### Modelle (`lib/data/model/`)

Organisiert nach Funktionen:

- `server/` - Server-Verbindung und Status-Modelle
- `container/` - Docker-Container-Modelle
- `ssh/` - SSH-Sitzungs-Modelle
- `sftp/` - SFTP-Datei-Modelle
- `app/` - App-spezifische Modelle

### Provider (`lib/data/provider/`)

Riverpod Provider für Dependency Injection und Zustandsverwaltung:

- Server Provider
- UI-Zustands-Provider
- Service Provider

### Stores (`lib/data/store/`)

Hive-basierte lokale Speicherung:

- Server-Speicher
- Einstellungs-Speicher
- Cache-Speicher

## UI-Schicht (`lib/view/`)

### Seiten (`lib/view/page/`)

Hauptbildschirme der Anwendung:

- `server/` - Server-Verwaltungsseiten
- `ssh/` - SSH-Terminal-Seiten
- `container/` - Container-Seiten
- `setting/` - Einstellungsseiten
- `storage/` - SFTP-Seiten
- `snippet/` - Snippet-Seiten

### Widgets (`lib/view/widget/`)

Wiederverwendbare UI-Komponenten:

- Server-Karten
- Status-Diagramme
- Eingabe-Komponenten
- Dialoge

## Generierte Dateien

- `lib/generated/l10n/` - Automatisch generierte Lokalisierung
- `*.g.dart` - Generierter Code (json_serializable, freezed, hive, riverpod)
- `*.freezed.dart` - Unveränderliche Freezed-Klassen

## Verzeichnis "packages" (`/packages/`)

Enthält eigene Forks von Abhängigkeiten:

- `dartssh2/` - SSH-Bibliothek
- `xterm/` - Terminal-Emulator
- `fl_lib/` - Gemeinsame Dienstprogramme
- `fl_build/` - Build-System

## Rust-Seite

- `crates/sbm_parser/` - Parst rohe Befehlsausgaben in strukturierten Serverstatus.
  Von App (via FFI) und Monitor gemeinsam genutzt, beide parsen daher immer identisch.
- `crates/sbm_ffi/` - Dünner flutter_rust_bridge-Wrapper um `sbm_parser`.
  Die generierte Dart-Seite liegt in `lib/src/rust/`.
- `monitor/` - Eigenständiger Monitoring-Dienst, Dokumentation in `monitor/README.md`.
