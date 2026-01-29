---
title: Terminal-Implementierung
description: Wie das SSH-Terminal intern funktioniert
---

Das SSH-Terminal ist eine der komplexesten Funktionen, aufgebaut auf einem benutzerdefinierten xterm.dart-Fork.

## Architektur-Übersicht

```
┌─────────────────────────────────────────────┐
│          Terminal UI Schicht                │
│  - Tab-Management                           │
│  - Virtuelle Tastatur                       │
│  - Textauswahl                              │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│         xterm.dart Emulator                 │
│  - PTY (Pseudo Terminal)                    │
│  - VT100/ANSI Emulation                     │
│  - Rendering-Engine                         │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          SSH-Client-Schicht                 │
│  - SSH-Sitzung                              │
│  - Kanalverwaltung                          │
│  - Daten-Streaming                          │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          Remote-Server                      │
│  - Shell-Prozess                            │
│  - Befehlsausführung                        │
└─────────────────────────────────────────────┘
```

## Lebenszyklus einer Terminal-Sitzung

### 1. Sitzungserstellung

```dart
Future<TerminalSession> createSession(Spi spi) async {
  // 1. SSH-Client abrufen
  final client = await genClient(spi);

  // 2. PTY erstellen
  final pty = await client.openPty(
    term: 'xterm-256color',
    cols: 80,
    rows: 24,
  );

  // 3. Terminal-Emulator initialisieren
  final terminal = Terminal(
    backend: PtyBackend(pty),
  );

  // 4. Resize-Handler einrichten
  terminal.onResize.listen((size) {
    pty.resize(size.cols, size.rows);
  });

  return TerminalSession(
    terminal: terminal,
    pty: pty,
    client: client,
  );
}
```

### 2. Terminal-Emulation

Der xterm.dart-Fork bietet:

**VT100/ANSI Emulation:**
- Cursor-Bewegung
- Farben (256-Farben-Unterstützung)
- Textattribute (fett, unterstrichen, usw.)
- Scroll-Bereiche
- Alternativer Bildschirmpuffer

**Rendering:**
- Zeilenbasiertes Rendering
- Unterstützung für bidirektionalen Text
- Unicode/Emoji Unterstützung
- Optimierte Redraws

### 3. Datenfluss

```
Benutzereingabe
    ↓
Virtuelle Tastatur / Physische Tastatur
    ↓
Terminal-Emulator (Taste → Escape-Sequenz)
    ↓
SSH-Kanal (senden)
    ↓
Remote PTY
    ↓
Remote Shell
    ↓
Befehlsausgabe
    ↓
SSH-Kanal (empfangen)
    ↓
Terminal-Emulator (Analyse von ANSI-Codes)
    ↓
Rendering auf dem Bildschirm
```

## Multi-Tab System

### Tab-Management

Tabs behalten ihren Zustand bei Navigationswechseln bei:
- SSH-Verbindung bleibt aktiv
- Terminalzustand bleibt erhalten
- Scroll-Puffer bleibt bestehen
- Eingabeverlauf bleibt erhalten

## Virtuelle Tastatur

### Plattformspezifische Implementierung

**iOS:**
- UIView-basierte benutzerdefinierte Tastatur
- Umschaltbar mit Tastatur-Button
- Automatisches Ein-/Ausblenden basierend auf dem Fokus

**Android:**
- Benutzerdefinierte Eingabemethode
- Integriert in die Systemtastatur
- Schnellaktionstasten

### Tastatur-Buttons

| Button | Aktion |
|--------|--------|
| **Umschalten** | Systemtastatur ein-/ausblenden |
| **Ctrl** | Ctrl-Modifikator senden |
| **Alt** | Alt-Modifikator senden |
| **SFTP** | Aktuelles Verzeichnis öffnen |
| **Zwischenablage** | Kontextsensitive Kopieren/Einfügen |
| **Snippets** | Snippet ausführen |

## Textauswahl

1. **Langes Drücken**: Auswahlmodus aktivieren
2. **Ziehen**: Auswahl erweitern
3. **Loslassen**: In die Zwischenablage kopieren

## Schriftart und Dimensionen

### Größenberechnung

```dart
class TerminalDimensions {
  static Size calculate(double fontSize, Size screenSize) {
    final charWidth = fontSize * 0.6;  // Monospace-Seitenverhältnis
    final charHeight = fontSize * 1.2;

    final cols = (screenSize.width / charWidth).floor();
    final rows = (screenSize.height / charHeight).floor();

    return Size(cols.toDouble(), rows.toDouble());
  }
}
```

### Pinch-to-Zoom

```dart
GestureDetector(
  onScaleStart: () => _baseFontSize = currentFontSize,
  onScaleUpdate: (details) {
    final newFontSize = _baseFontSize * details.scale;
    resize(newFontSize);
  },
)
```

## Farbschema

- **Hell (Light)**: Heller Hintergrund, dunkler Text
- **Dunkel (Dark)**: Dunkler Hintergrund, heller Text
- **AMOLED**: Rein schwarzer Hintergrund

## Leistungsoptimierungen

- **Dirty Rectangle**: Nur geänderte Regionen neu zeichnen
- **Zeilen-Caching**: Gerenderte Zeilen cachen
- **Lazy Scrolling**: Virtuelles Scrollen für lange Puffer
- **Batch-Updates**: Mehrere Schreibvorgänge zusammenfassen
- **Kompression**: Kompression des Scroll-Puffers
- **Debouncing**: Debouncing für schnelle Eingaben
