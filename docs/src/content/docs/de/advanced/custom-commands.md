---
title: Benutzerdefinierte Befehle
description: Anzeige der Ausgabe benutzerdefinierter Befehle auf der Serverseite
---

Fügen Sie benutzerdefinierte Shell-Befehle hinzu, um deren Ausgabe auf der Server-Detailseite anzuzeigen.

## Einrichtung

1. Servereinstellungen → Benutzerdefinierte Befehle
2. Befehle im JSON-Format eingeben

## Basisformat

```json
{
  "Anzeigename": "Shell-Befehl"
}
```

**Beispiel:**
```json
{
  "Speicher": "free -h",
  "Festplatte": "df -h",
  "Laufzeit": "uptime"
}
```

## Ergebnisse anzeigen

Nach der Einrichtung erscheinen benutzerdefinierte Befehle auf der Server-Detailseite und werden automatisch aktualisiert.

## Spezielle Befehlsnamen

### server_card_top_right

Anzeige auf der Serverkarte der Startseite (oben rechts):

```json
{
  "server_card_top_right": "Ihr-Befehl-hier"
}
```

## Tipps

**Absolute Pfade verwenden:**
```json
{"Mein Skript": "/usr/local/bin/mein-skript.sh"}
```

**Pipe-Befehle:**
```json
{"Top-Prozess": "ps aux | sort -rk 3 | head -5"}
```

**Ausgabe formatieren:**
```json
{"CPU-Last": "uptime | awk -F'load average:' '{print $2}'"}
```

**Befehle schnell halten:** Unter 5 Sekunden für das beste Erlebnis.

**Ausgabe begrenzen:**
```json
{"Logs": "tail -20 /var/log/syslog"}
```

## Sicherheit

Befehle werden mit den Berechtigungen des SSH-Benutzers ausgeführt. Vermeiden Sie Befehle, die den Systemzustand ändern.
