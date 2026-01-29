---
title: Startbildschirm-Widgets
description: Fügen Sie Serverstatus-Widgets zu Ihrem Startbildschirm hinzu
---

Erfordert [ServerBox Monitor](https://github.com/lollipopkit/server_box_monitor) auf Ihren Servern installiert.

## Voraussetzungen

Installieren Sie zuerst ServerBox Monitor auf Ihrem Server. Anweisungen zur Einrichtung finden Sie im [ServerBox Monitor Wiki](https://github.com/lollipopkit/server_box_monitor/wiki/Home).

Nach der Installation sollte Ihr Server verfügen über:
- Einen HTTP/HTTPS-Endpunkt
- Einen `/status` API-Endpunkt
- Optionale Authentifizierung

## URL-Format

```
https://ihr-server.com/status
```

Muss auf `/status` enden.

## iOS-Widget

### Einrichtung

1. Startbildschirm lange drücken → Auf **+** tippen
2. Nach "ServerBox" suchen
3. Widget-Größe wählen
4. Widget lange drücken → **Widget bearbeiten**
5. URL eingeben, die auf `/status` endet

### Hinweise

- Muss HTTPS verwenden (außer bei lokalen IPs)
- Maximale Aktualisierungsrate: 30 Minuten (iOS-Limit)
- Fügen Sie mehrere Widgets für mehrere Server hinzu

## Android-Widget

### Einrichtung

1. Startbildschirm lange drücken → **Widgets**
2. "ServerBox" finden → Zum Startbildschirm hinzufügen
3. Notieren Sie sich die angezeigte Widget-ID-Nummer
4. ServerBox-App öffnen → Einstellungen
5. Tippen Sie auf **Config home widget link**
6. Eintrag hinzufügen: `Widget ID` = `Status-URL`

Beispiel:
- Key: `17`
- Value: `https://mein-server.com/status`

7. Tippen Sie auf das Widget auf dem Startbildschirm, um es zu aktualisieren

## watchOS-Widget

### Einrichtung

1. iPhone-App öffnen → Einstellungen
2. **iOS-Einstellungen** → **Watch-App**
3. Auf **URL hinzufügen** tippen
4. URL eingeben, die auf `/status` endet
5. Warten, bis die Watch-App synchronisiert ist

### Hinweise

- Versuchen Sie, die Watch-App neu zu starten, wenn sie nicht aktualisiert wird
- Sicherstellen, dass Telefon und Watch verbunden sind

## Fehlerbehebung

### Widget aktualisiert nicht

**iOS:** Warten Sie bis zu 30 Minuten, dann entfernen Sie es und fügen es erneut hinzu.
**Android:** Tippen Sie auf das Widget, um die Aktualisierung zu erzwingen, überprüfen Sie die ID in den Einstellungen.
**watchOS:** Starten Sie die Watch-App neu, warten Sie einige Minuten.

### Widget zeigt Fehler an

- Sicherstellen, dass ServerBox Monitor läuft
- URL im Browser testen
- Prüfen, ob die URL auf `/status` endet

## Sicherheit

- **Verwenden Sie immer HTTPS**, wann immer möglich
- **Lokale IPs nur** in vertrauenswürdigen Netzwerken
