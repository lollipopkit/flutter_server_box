---
title: Projektstruktur
description: Verständnis der Server Box Codebasis
---

Das Server Box-Projekt folgt einer modularen Architektur mit einer klaren Trennung der Belange.

## Verzeichnisstruktur

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
