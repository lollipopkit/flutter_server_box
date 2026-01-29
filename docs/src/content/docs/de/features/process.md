---
title: Prozesse & Dienste
description: Prozesse überwachen und systemd-Dienste verwalten
---

## Prozessverwaltung

Anzeige und Verwaltung laufender Prozesse auf Ihren Servern.

### Prozessliste

- Alle laufenden Prozesse mit Details
- PID (Prozess-ID)
- CPU- und Speicherauslastung
- Benutzerzugehörigkeit
- Prozessbefehl

### Prozessaktionen

- **Beenden (Kill)**: Prozesse terminieren
- **Filtern**: Nach Name oder Benutzer
- **Sortieren**: Nach CPU, Speicher oder PID
- **Suchen**: Bestimmte Prozesse finden

## Systemd-Dienste

Verwalten von systemd-Diensten zur Dienststeuerung.

### Dienstliste

- Alle systemd-Dienste
- Status (Aktiv/Inaktiv)
- Status (Aktiviert/Deaktiviert)
- Dienstbeschreibung

### Dienstaktionen

- **Starten**: Einen gestoppten Dienst starten
- **Stoppen**: Einen laufenden Dienst stoppen
- **Neustarten**: Einen Dienst neu starten
- **Aktivieren**: Autostart beim Booten aktivieren
- **Deaktivieren**: Autostart deaktivieren
- **Status anzeigen**: Dienststatus und Logs prüfen
- **Neu laden**: Dienstkonfiguration neu laden

## Voraussetzungen

- Der SSH-Benutzer muss über entsprechende Berechtigungen verfügen
- Für die Dienstverwaltung: `sudo`-Zugriff kann erforderlich sein
- Prozessanzeige: Standard-Benutzerberechtigungen sind in der Regel ausreichend

## Tipps

- Nutzen Sie die Prozessliste, um Ressourcenfresser zu identifizieren
- Prüfen Sie die Dienstlogs zur Fehlerbehebung
- Überwachen Sie kritische Dienste mit der automatischen Aktualisierung
