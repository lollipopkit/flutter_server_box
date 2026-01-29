---
title: Docker-Verwaltung
description: Docker-Container überwachen und verwalten
---

Server Box bietet eine intuitive Benutzeroberfläche zur Verwaltung von Docker-Containern auf Ihren Servern.

## Funktionen

### Container-Liste

- Alle Container anzeigen (laufend und gestoppt)
- Anzeige von Container-ID und Name
- Image-Informationen
- Statusanzeigen
- Erstellungszeit

### Container-Aktionen

- **Starten**: Gestoppte Container starten
- **Stoppen**: Laufende Container ordnungsgemäß stoppen
- **Neustarten**: Container neu starten
- **Entfernen**: Container löschen
- **Logs anzeigen**: Container-Logs prüfen
- **Inspizieren**: Container-Details anzeigen

### Container-Details

- Umgebungsvariablen
- Port-Mappings
- Volume-Mounts
- Netzwerkkonfiguration
- Ressourcennutzung

## Voraussetzungen

- Docker muss auf Ihrem Server installiert sein
- Der SSH-Benutzer muss über Docker-Berechtigungen verfügen
- Für Nicht-Root-Benutzer zur Docker-Gruppe hinzufügen:
  ```bash
  sudo usermod -aG docker ihr_benutzername
  ```

## Schnellaktionen

- Einfaches Tippen: Container-Details anzeigen
- Langes Drücken: Schnellaktionsmenü
- Wischen: Schnellstart/-stopp
- Mehrfachauswahl: Operationen für mehrere Container

## Tipps

- Nutzen Sie die **automatische Aktualisierung**, um Statusänderungen von Containern zu überwachen
- Filtern nach laufenden/gestoppten Containern
- Container nach Name oder ID suchen
