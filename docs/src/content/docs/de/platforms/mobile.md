---
title: Mobile Funktionen
description: Spezifische Funktionen für iOS und Android
---

Flutter Server Box bietet mehrere mobile-spezifische Funktionen für iOS- und Android-Geräte.

## Biometrische Authentifizierung

Sichern Sie Ihre Server mit biometrischer Authentifizierung:

- **iOS**: Face ID oder Touch ID
- **Android**: Fingerabdruck-Authentifizierung

Aktivieren Sie dies unter Einstellungen > Sicherheit > Biometrische Authentifizierung.

## Startbildschirm-Widgets

Fügen Sie Serverstatus-Widgets zu Ihrem Startbildschirm für eine schnelle Überwachung hinzu.

### iOS

- Auf den Startbildschirm lange drücken
- Auf **+** tippen, um ein Widget hinzuzufügen
- Nach "Flutter Server Box" suchen
- Widget-Größe wählen:
  - Klein: Status eines einzelnen Servers
  - Mittel: Mehrere Server
  - Groß: Detaillierte Informationen

### Android

- Auf den Startbildschirm lange drücken
- Auf **Widgets** tippen
- "Flutter Server Box" finden
- Widget-Typ auswählen

## Hintergrundbetrieb

### Android

Verbindungen im Hintergrund aufrechterhalten:

- Aktivieren unter Einstellungen > Erweitert > Hintergrundbetrieb
- Erfordert Ausschluss von der Akku-Optimierung
- Permanente Benachrichtigungen für aktive Verbindungen

### iOS

Es gelten Hintergrundbeschränkungen:

- Verbindungen können im Hintergrund pausieren
- Schnelle Wiederverbindung bei Rückkehr zur App
- Unterstützung für Hintergrundaktualisierung

## Push-Benachrichtigungen

Erhalten Sie Benachrichtigungen für:

- Server-Offline-Alarme
- Warnungen bei hoher Ressourcenauslastung
- Alarme bei Abschluss von Aufgaben

Konfigurieren unter Einstellungen > Benachrichtigungen.

## Mobile UI-Funktionen

- **Pull to Refresh**: Serverstatus aktualisieren
- **Wischgesten**: Schnelle Serveroperationen
- **Querformat**: Besseres Terminal-Erlebnis
- **Virtuelle Tastatur**: Terminal-Shortcuts

## Datei-Integration

- **Dateien-App (iOS)**: Direkter SFTP-Zugriff aus Dateien
- **Storage Access Framework (Android)**: Dateien mit anderen Apps teilen
- **Dokumentenauswahl**: Einfache Dateiauswahl
