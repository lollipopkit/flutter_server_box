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

Die virtuelle Tastatur ist auf allen Plattformen ein Flutter-Widget, das über dem
Terminal angezeigt wird (verfügbare Tasten sind in
`lib/data/model/ssh/virtual_key.dart` definiert). Auf Mobilgeräten erscheint sie
zusammen mit der Systemtastatur.

### Tastatur-Buttons

| Button | Aktion |
|--------|--------|
| **Esc / Tab / Home / End / PgUp / PgDn / Pfeiltasten** | Entsprechende Taste senden |
| **Ctrl / Alt / Shift** | Modifikator für die nächste Taste umschalten |
| **IME** | Systemtastatur ein-/ausblenden |
| **Zwischenablage** | Kontextabhängiges Kopieren/Einfügen |
| **SFTP** | Aktuelles Verzeichnis im SFTP-Browser öffnen |
| **Snippet** | Snippet auswählen und ausführen |
| **Symbole** | `/ \ _ + = - ( ) [ ] { } < >` und mehr |

Tastensatz und Reihenfolge sind in den Einstellungen anpassbar.

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

## Leistung

Der xterm.dart-Fork rendert mit einem eigenen Painter und zeichnet nur bei
Terminal-Updates neu; Ausgaben werden gepuffert und zusammengefasst, bevor sie
an den Emulator übergeben werden.

## Besondere Funktionen

### Snippet-Ausführung

Beim Auswählen eines Snippets wird dessen Inhalt in das Terminal eingefügt und mit
einem Zeilenumbruch ausgeführt.

### SFTP-Schnellzugriff

Die virtuelle **SFTP**-Taste öffnet das aktuelle Arbeitsverzeichnis im SFTP-Browser.

### Keep-Alive

Verbindungen werden auf der SSH-Protokollebene aufrechterhalten (siehe
[SSH-Verbindung](/docs/principles/ssh/)), nicht durch Einspeisen von Bytes ins Terminal.
