---
title: Architektur
description: Architekturmuster und Designentscheidungen
---

Server Box folgt den Prinzipien der Clean Architecture mit einer klaren Trennung zwischen Daten-, Domänen- und Präsentationsschicht.

## Schichtarchitektur

```
┌─────────────────────────────────────┐
│          Präsentationsschicht       │
│         (lib/view/page/)            │
│  - Seiten, Widgets, Controller      │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│         Business-Logik-Schicht     │
│      (lib/data/provider/)           │
│  - Riverpod Provider               │
│  - Zustandsverwaltung              │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│           Datenschicht              │
│      (lib/data/model/, store/)      │
│  - Modelle, Speicher, Dienste       │
└─────────────────────────────────────┘
```

## Schlüsselmuster

### Zustandsverwaltung: Riverpod

- **Codegenerierung**: Verwendet `riverpod_generator` für typsichere Provider
- **State Notifier**: Für veränderlichen Zustand mit Business-Logik
- **Async Notifier**: Für Lade- und Fehlerzustände
- **Stream Provider**: Für Echtzeitdaten

### Unveränderliche Modelle: Freezed

- Alle Datenmodelle verwenden Freezed für Unveränderlichkeit
- Union-Typen zur Darstellung von Zuständen
- Integrierte JSON-Serialisierung
- CopyWith-Erweiterungen für Aktualisierungen

### Lokale Speicherung: Hive

- **hive_ce**: Community-Edition von Hive
- Keine manuellen `@HiveField` oder `@HiveType` erforderlich
- Typ-Adapter werden automatisch generiert
- Persistenter Key-Value-Speicher

## Dependency Injection

Dienste und Stores werden injiziert über:

1. **Provider**: Stellen Abhängigkeiten der UI zur Verfügung
2. **GetIt**: Service-Locator (wo anwendbar)
3. **Konstruktor-Injektion**: Explizite Abhängigkeiten

## Datenfluss

```
Benutzeraktion → Widget → Provider → Dienst/Store → Modell-Update → UI-Neuaufbau
```

1. Benutzer interagiert mit Widget
2. Widget ruft Provider-Methode auf
3. Provider aktualisiert Zustand über Dienst/Store
4. Zustandsänderung löst Neuaufbau der UI aus
5. Neuer Zustand spiegelt sich im Widget wider

## Eigene Abhängigkeiten

Das Projekt verwendet mehrere eigene Forks zur Funktionserweiterung:

- **dartssh2**: Erweiterte SSH-Funktionen
- **xterm**: Terminal-Emulator mit mobiler Unterstützung
- **fl_lib**: Gemeinsame UI-Komponenten und Dienstprogramme

## Threading

- **Isolates**: Rechenintensive Aufgaben außerhalb des Main-Threads
- **computer-Paket**: Dienstprogramme für Multi-Threading
- **Async/Await**: Nicht-blockierende I/O-Operationen
