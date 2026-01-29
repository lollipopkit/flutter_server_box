---
title: Netzwerk-Tools
description: Netzwerk-Test- und Diagnose-Tools
---

Server Box enthält verschiedene Netzwerk-Tools für Tests und Diagnosen.

## iPerf

Führen Sie Netzwerkgeschwindigkeitstests zwischen Ihrem Gerät und dem Server durch.

### Funktionen

- **Upload-/Download-Geschwindigkeit**: Bandbreite testen
- **Server-Modus**: Server als iPerf-Server nutzen
- **Client-Modus**: Verbindung zu iPerf-Servern herstellen
- **Benutzerdefinierte Parameter**: Dauer, parallele Streams usw.

### Verwendung

1. Öffnen Sie einen Server
2. Tippen Sie auf **iPerf**
3. Wählen Sie den Server- oder Client-Modus
4. Konfigurieren Sie die Parameter
5. Starten Sie den Test

## Ping

Testen Sie die Netzwerkkonnektivität und Latenz.

### Funktionen

- **ICMP Ping**: Standard-Ping-Tool
- **Paketanzahl**: Anzahl der Pakete angeben
- **Paketgröße**: Benutzerdefinierte Paketgröße
- **Intervall**: Zeit zwischen Pings

### Verwendung

1. Öffnen Sie einen Server
2. Tippen Sie auf **Ping**
3. Geben Sie den Zielhost ein
4. Konfigurieren Sie die Parameter
5. Starten Sie den Ping-Vorgang

## Wake on LAN

Wecken Sie Remote-Server per Magic Packet auf.

### Funktionen

- **MAC-Adresse**: MAC des Zielgeräts
- **Broadcast**: Senden eines Broadcast Magic Packets
- **Gespeicherte Profile**: WoL-Konfigurationen speichern

### Voraussetzungen

- Das Zielgerät muss Wake-on-LAN unterstützen
- WoL muss im BIOS/UEFI aktiviert sein
- Das Gerät muss sich im Ruhezustand oder Soft-Off-Zustand befinden
- Das Gerät muss sich im selben Netzwerk befinden oder über Broadcast erreichbar sein

## Tipps

- Nutzen Sie iPerf, um Netzwerkengpässe zu diagnostizieren
- Pingen Sie mehrere Hosts, um Latenzen zu vergleichen
- Speichern Sie WoL-Profile für häufig geweckte Geräte
