---
title: Mobile Funktionen
description: Spezifische Funktionen für iOS und Android
---

Server Box bietet mehrere mobile-spezifische Funktionen für iOS- und Android-Geräte.

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
- Nach "Server Box" suchen
- Widget-Größe wählen:
  - Klein: Status eines einzelnen Servers
  - Mittel: Mehrere Server
  - Groß: Detaillierte Informationen

### Android

- Auf den Startbildschirm lange drücken
- Auf **Widgets** tippen
- "Server Box" finden
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

Server-Warnungen (offline, Schwellenwert überschritten) werden vom
[ServerBox Monitor](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor)
auf Ihren Servern gesendet — Warnregeln und Push-Kanäle werden dort konfiguriert.

## Mobile UI-Funktionen

- **Pull-to-Refresh**: Serverstatus aktualisieren
- **Querformat**: Bessere Terminal-Erfahrung
- **Virtuelle Tastatur**: Terminal-Kurzbefehle

## Dateiintegration

- **Dokumentauswahl**: Lokale Dateien für SFTP-Upload und Backup-Import/-Export auswählen
- **Teilen**: Dateien an andere Apps exportieren
