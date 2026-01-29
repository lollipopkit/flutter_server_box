---
title: Proxmox (PVE)
description: Proxmox Virtual Environment Verwaltung
---

Server Box bietet Unterstützung für die Verwaltung der Virtualisierungsplattform Proxmox VE.

## Funktionen

### VM-Verwaltung

- **VMs auflisten**: Alle virtuellen Maschinen anzeigen
- **VM-Status**: Status (laufend/gestoppt) prüfen
- **VM-Aktionen**: VMs starten, stoppen, neu starten
- **VM-Details**: Konfiguration und Ressourcen anzeigen

### Container (LXC) Verwaltung

- **Container auflisten**: Alle LXC-Container anzeigen
- **Container-Status**: Status von Containern überwachen
- **Container-Aktionen**: Container starten, stoppen, neu starten
- **Konsolenzugriff**: Terminalzugriff auf Container

### Knoten-Überwachung

- **Ressourcennutzung**: CPU, Arbeitsspeicher, Festplatte, Netzwerk
- **Knotenstatus**: Knotengesundheit prüfen
- **Cluster-Ansicht**: Übersicht über Multi-Knoten-Cluster

## Einrichtung

### PVE-Server hinzufügen

1. Server als normale SSH-Verbindung hinzufügen
2. Sicherstellen, dass der Benutzer über PVE-Berechtigungen verfügt
3. Zugriff auf PVE-Funktionen über die Server-Detailseite

### Erforderliche Berechtigungen

Der PVE-Benutzer benötigt:

- **VM.Audit**: VM-Status anzeigen
- **VM.PowerMgmt**: VMs starten/stoppen
- **VM.Console**: Konsolenzugriff

Beispiel für die Einrichtung der Berechtigungen:

```bash
pveum useradd myuser -password mypass
pveum aclmod /vms -user myuser@pve -role VMAdmin
```

## Verwendung

### VM-Verwaltung

1. Server mit PVE öffnen
2. Auf die Schaltfläche **PVE** tippen
3. VM-Liste anzeigen
4. VM für Details auswählen
5. Aktionsschaltflächen zur Verwaltung nutzen

### Container-Verwaltung

1. Server mit PVE öffnen
2. Auf die Schaltfläche **PVE** tippen
3. Zum Tab "Container" wechseln
4. LXC-Container anzeigen und verwalten

### Überwachung

- Echtzeit-Ressourcennutzung
- Historische Datendiagramme
- Unterstützung für mehrere Knoten

## Funktionen nach Status

### Implementiert

- VM-Auflistung und Status
- Container-Auflistung und Status
- Grundlegende VM-Operationen (Start/Stopp/Neustart)
- Ressourcen-Überwachung

### Geplant

- VM-Erstellung aus Vorlagen
- Snapshot-Verwaltung
- Konsolenzugriff
- Speicherverwaltung
- Netzwerkkonfiguration

## Voraussetzungen

- **PVE-Version**: 6.x oder 7.x
- **Zugriff**: SSH-Zugriff auf den PVE-Host
- **Berechtigungen**: Entsprechende PVE-Benutzerrollen
- **Netzwerk**: Erreichbarkeit der PVE-API (über SSH)

## Tipps

- Verwenden Sie einen **dedizierten PVE-Benutzer** mit eingeschränkten Berechtigungen
- Überwachen Sie die **Ressourcennutzung** für optimale Leistung
- Prüfen Sie den **VM-Status** vor Wartungsarbeiten
- Erstellen Sie **Snapshots** vor größeren Änderungen
