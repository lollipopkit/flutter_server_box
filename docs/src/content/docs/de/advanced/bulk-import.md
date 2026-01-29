---
title: Massenimport von Servern
description: Importieren Sie mehrere Server aus einer JSON-Datei
---

Importieren Sie mehrere Serverkonfigurationen gleichzeitig mithilfe einer JSON-Datei.

## JSON-Format

:::danger[Sicherheitswarnung]
**Speichern Sie niemals Klartext-Passwörter in Dateien!** Dieses JSON-Beispiel zeigt ein Passwort-Feld nur zur Demonstration, aber Sie sollten:

- **SSH-Schlüssel bevorzugen** (`keyId`) anstelle von `pwd` - diese sind sicherer
- **Passwort-Manager** oder Umgebungsvariablen verwenden, wenn Sie Passwörter verwenden müssen
- **Löschen Sie die Datei sofort** nach dem Import - lassen Sie keine Anmeldedaten herumliegen
- **Fügen Sie sie zur .gitignore hinzu** - checken Sie niemals Anmeldedatendateien in die Versionsverwaltung ein
:::

```json
[
  {
    "name": "Mein Server",
    "ip": "example.com",
    "port": 22,
    "user": "root",
    "pwd": "password",
    "keyId": "",
    "tags": ["production"],
    "autoConnect": false
  }
]
```

## Felder

| Feld | Erforderlich | Beschreibung |
|-------|----------|-------------|
| `name` | Ja | Anzeigename |
| `ip` | Ja | Domain oder IP-Adresse |
| `port` | Ja | SSH-Port (normalerweise 22) |
| `user` | Ja | SSH-Benutzername |
| `pwd` | Nein | Passwort (vermeiden - stattdessen SSH-Schlüssel verwenden) |
| `keyId` | Nein | SSH-Schlüsselname (aus Private Keys - empfohlen) |
| `tags` | Nein | Organisations-Tags |
| `autoConnect` | Nein | Automatische Verbindung beim Start |

## Import-Schritte

1. Erstellen Sie eine JSON-Datei mit Serverkonfigurationen
2. Einstellungen → Backup → Server massenhaft importieren
3. Wählen Sie Ihre JSON-Datei aus
4. Bestätigen Sie den Import

## Beispiel

```json
[
  {
    "name": "Produktion",
    "ip": "prod.example.com",
    "port": 22,
    "user": "admin",
    "keyId": "my-key",
    "tags": ["production", "web"]
  },
  {
    "name": "Entwicklung",
    "ip": "dev.example.com",
    "port": 2222,
    "user": "dev",
    "keyId": "dev-key",
    "tags": ["development"]
  }
]
```

## Tipps

- **Verwenden Sie SSH-Schlüssel** anstelle von Passwörtern, wann immer möglich
- **Testen Sie die Verbindung** nach dem Import
- **Organisieren Sie mit Tags** für eine einfachere Verwaltung
- **Löschen Sie die JSON-Datei** nach dem Import
- **Checken Sie niemals** JSON-Dateien mit Anmeldedaten in die Versionsverwaltung ein
