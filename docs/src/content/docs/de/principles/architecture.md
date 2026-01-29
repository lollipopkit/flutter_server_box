---
title: Architektur-Übersicht
description: High-Level-Anwendungsarchitektur
---

Flutter Server Box folgt einer Schichtarchitektur mit klarer Trennung der Belange (Separation of Concerns).

## Architektur-Schichten

```
┌─────────────────────────────────────────────────┐
│          Präsentationsschicht (UI)             │
│          lib/view/page/, lib/view/widget/       │
│  - Seiten, Widgets, Controller                   │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│         Business-Logik-Schicht                 │
│         lib/data/provider/                      │
│  - Riverpod Provider, State Notifier            │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│           Datenzugriffsschicht                  │
│         lib/data/store/, lib/data/model/        │
│  - Hive Stores, Datenmodelle                     │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│         Externe Integrationsschicht             │
│  - SSH (dartssh2), Terminal (xterm), SFTP       │
│  - Plattformspezifischer Code (iOS, Android etc.)│
└─────────────────────────────────────────────────┘
```

## Anwendungsgrundlagen

### Haupteinstiegspunkt

`lib/main.dart` initialisiert die App:

```dart
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### Root-Widget

`MyApp` bietet:
- **Theme-Management**: Umschalten zwischen hellem/dunklem Theme
- **Routing-Konfiguration**: Navigationsstruktur
- **Provider Scope**: Wurzel für Dependency Injection

### Startseite

`HomePage` dient als Navigationszentrum:
- **Tab-Interface**: Server, Snippet, Container, SSH
- **Zustandsverwaltung**: Zustand pro Tab
- **Navigation**: Funktionszugriff

## Kernsysteme

### Zustandsverwaltung: Riverpod

**Warum Riverpod?**
- Sicherheit zur Kompilierzeit
- Einfache Testbarkeit
- Keine Abhängigkeit vom Build-Kontext
- Funktioniert plattformübergreifend

**Verwendete Provider-Typen:**
- `StateProvider`: Einfacher veränderlicher Zustand
- `AsyncNotifierProvider`: Lade-/Fehler-/Datenzustände
- `StreamProvider`: Echtzeit-Datenströme
- Future Provider: Einmalige asynchrone Operationen

### Datenpersistenz: Hive CE

**Warum Hive CE?**
- Keine Abhängigkeiten von nativem Code
- Schneller Key-Value-Speicher
- Typsicher durch Codegenerierung
- Keine manuellen Feld-Annotationen erforderlich

**Stores:**
- `SettingStore`: App-Einstellungen
- `ServerStore`: Server-Konfigurationen
- `SnippetStore`: Befehls-Snippets
- `KeyStore`: SSH-Schlüssel

### Immutable Modelle: Freezed

**Vorteile:**
- Unveränderlichkeit zur Kompilierzeit
- Union Types für Zustände
- Integrierte JSON-Serialisierung
- CopyWith-Erweiterungen

## Cross-Plattform-Strategie

### Plugin-System

Flutter-Plugins ermöglichen die Plattformintegration:

| Plattform | Integrationsmethode |
|-----------|--------------------|
| iOS | CocoaPods, Swift/Obj-C |
| Android | Gradle, Kotlin/Java |
| macOS | CocoaPods, Swift |
| Linux | CMake, C++ |
| Windows | CMake, C# |

### Plattformspezifische Funktionen

**Nur iOS:**
- Startbildschirm-Widgets
- Live-Aktivitäten
- Apple Watch Begleit-App

**Nur Android:**
- Hintergrunddienst
- Push-Benachrichtigungen
- Dateisystemzugriff

**Nur Desktop:**
- Menüleisten-Integration
- Mehrere Fenster
- Benutzerdefinierte Titelleiste

## Eigene Abhängigkeiten

### dartssh2 Fork

Erweiterter SSH-Client mit:
- Besserer mobiler Unterstützung
- Verbesserter Fehlerbehandlung
- Leistungsoptimierungen

### xterm.dart Fork

Terminal-Emulator mit:
- Für Mobilgeräte optimiertem Rendering
- Unterstützung für Touch-Gesten
- Integration der virtuellen Tastatur

### fl_lib

Paket mit gemeinsamen Dienstprogrammen:
- Gemeinsame Widgets
- Erweiterungen
- Hilfsfunktionen

## Build-System

### fl_build Paket

Eigenes Build-System für:
- Multi-Plattform-Builds
- Code-Signierung
- Asset-Bündelung
- Versionsverwaltung

### Build-Prozess

```
make.dart (Version) → fl_build (Build) → Plattform-Output
```

1. **Pre-build**: Berechnung der Version aus Git
2. **Build**: Kompilierung für die Zielplattform
3. **Post-build**: Paketierung und Signierung

## Beispiel für den Datenfluss

### Aktualisierung des Serverstatus

```
1. Timer löst aus →
2. Provider ruft Service auf →
3. Service führt SSH-Befehl aus →
4. Antwort wird in Modell geparst →
5. Zustand wird aktualisiert →
6. UI wird mit neuen Daten neu aufgebaut
```

### Ablauf einer Benutzeraktion

```
1. Benutzer tippt auf Schaltfläche →
2. Widget ruft Provider-Methode auf →
3. Provider aktualisiert Zustand →
4. Zustandsänderung löst Neuaufbau aus →
5. Neuer Zustand spiegelt sich in der UI wider
```

## Sicherheitsarchitektur

### Datenschutz

- **Passwörter**: Verschlüsselt mit flutter_secure_storage
- **SSH-Schlüssel**: Verschlüsselt gespeichert
- **Host-Fingerabdrücke**: Sicher gespeichert
- **Sitzungsdaten**: Werden nicht persistiert

### Verbindungssicherheit

- **Host-Key-Verifizierung**: MITM-Erkennung
- **Verschlüsselung**: Standard-SSH-Verschlüsselung
- **Kein Klartext**: Sensible Daten werden niemals im Klartext gespeichert
