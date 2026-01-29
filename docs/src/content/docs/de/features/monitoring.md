---
title: Server-Überwachung
description: Echtzeit-Serverstatus-Überwachung mit schönen Diagrammen
---

Flutter Server Box bietet eine umfassende Echtzeit-Überwachung der Gesundheit und Leistung Ihres Servers.

## Status-Karten

Die Server-Detailseite zeigt konfigurierbare Status-Karten für verschiedene Systemmetriken an. Sie können Karten in den Einstellungen aktivieren/deaktivieren.

### CPU-Überwachung

- Echtzeit-CPU-Auslastung in Prozent
- Aufschlüsselung der CPU-Auslastung pro Kern
- Historische Auslastungsdiagramme
- Informationen zur CPU-Frequenz

### Arbeitsspeicher-Überwachung

- **RAM-Auslastung**: Verwendeter vs. gesamter Speicher mit Prozentangabe
- **Swap-Auslastung**: Auslastung des Auslagerungsspeichers
- Indikatoren für Speicherdruck
- Historische Speichertrends

### Festplatten-Überwachung

- Auslastung der Einhängepunkte mit Prozentangabe
- Gesamt-, genutzter und freier Speicherplatz
- E/A-Statistiken
- Unterstützung für mehrere Festplatten

### Netzwerk-Überwachung

- Echtzeit-Upload-/Download-Geschwindigkeiten
- Diagramme zur Bandbreitennutzung
- Statistiken zu Netzwerkschnittstellen
- Gesamtmenge der übertragenen Daten

### Fortgeschrittene Metriken

- **GPU-Status**: Überwachung von NVIDIA- und AMD-GPUs
- **Temperatur**: CPU-, GPU- und Systemtemperaturen
- **Sensoren**: Lüftergeschwindigkeiten, Spannungen und andere Sensordaten
- **S.M.A.R.T**: Überwachung der Festplattengesundheit
- **Batterie**: USV- oder Batteriestatus (falls verfügbar)

## Anzeige anpassen

### Karten neu anordnen

1. Gehen Sie zu Einstellungen
2. Wählen Sie Server-Einstellungen
3. Ziehen Sie die Karten, um sie auf der Server-Detailseite neu anzuordnen

### Karten aktivieren/deaktivieren

1. Öffnen Sie die Detailseite eines Servers
2. Tippen Sie auf die Schaltfläche "Bearbeiten/Menü"
3. Schalten Sie einzelne Karten ein oder aus

## Automatische Aktualisierung

- Status-Karten werden automatisch aktualisiert
- Das Aktualisierungsintervall ist in den Einstellungen konfigurierbar
- Manuelle Aktualisierung per Pull-to-Refresh-Geste möglich

## Diagramme und Visualisierungen

- **Linien-Diagramme**: Historische Datentrends
- **Anzeige-Diagramme**: Aktuelle prozentuale Auslastung
- **Farbcodierung**: Visuelle Indikatoren für Statusstufen
- **Zoom**: Pinch-to-Zoom auf Diagrammen für detaillierte Ansichten
