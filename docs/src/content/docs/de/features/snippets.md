---
title: Snippets
description: Eigene Shell-Befehle speichern und ausführen
---

Snippets ermöglichen es Ihnen, häufig verwendete Shell-Befehle für eine schnelle Ausführung zu speichern.

## Snippets erstellen

1. Gehen Sie zum Tab **Snippets**
2. Tippen Sie auf die Schaltfläche **+**
3. Füllen Sie die Snippet-Details aus:
   - **Name**: Anzeigename für das Snippet
   - **Befehl**: Der auszuführende Shell-Befehl
   - **Beschreibung**: Optionale Notizen
4. Speichern Sie das Snippet

## Snippets verwenden

1. Öffnen Sie einen Server
2. Tippen Sie auf die Schaltfläche **Snippet**
3. Wählen Sie ein Snippet zur Ausführung aus
4. Sehen Sie die Ausgabe im Terminal

## Snippet-Funktionen

- **Schnellausführung**: Befehlsausführung mit einem Tippen
- **Variablen**: Server-spezifische Variablen verwenden
- **Organisation**: Zusammengehörige Snippets gruppieren
- **Import/Export**: Snippets zwischen Geräten teilen
- **Synchronisierung**: Optionale Cloud-Synchronisierung

## Beispiel-Snippets

### System-Update
```bash
sudo apt update && sudo apt upgrade -y
```

### Festplattenbereinigung
```bash
sudo apt autoremove -y && sudo apt clean
```

### Docker-Bereinigung
```bash
docker system prune -a
```

### Systemprotokolle anzeigen
```bash
journalctl -n 50 -f
```

## Tipps

- Verwenden Sie **aussagekräftige Namen** zur einfachen Identifizierung
- Fügen Sie **Kommentare** für komplexe Befehle hinzu
- Testen Sie Befehle, bevor Sie sie als Snippet speichern
- Organisieren Sie Snippets nach Kategorie oder Servertyp
