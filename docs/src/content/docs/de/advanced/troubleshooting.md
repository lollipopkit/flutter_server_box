---
title: Häufige Probleme
description: Lösungen für gängige Probleme
---

## Verbindungsprobleme

### SSH verbindet nicht

**Symptome:** Timeout, Verbindung abgelehnt, Authentifizierung fehlgeschlagen

**Lösungen:**

1. **Servertyp überprüfen:** Nur Unix-ähnliche Systeme werden unterstützt (Linux, macOS, Android/Termux)
2. **Manuell testen:** `ssh benutzer@server -p port`
3. **Firewall prüfen:** Port 22 muss offen sein
4. **Anmeldedaten prüfen:** Benutzername und Passwort/Schlüssel korrekt

### Häufige Verbindungsabbrüche

**Symptome:** Das Terminal trennt die Verbindung nach Inaktivität

**Lösungen:**

1. **Server Keep-Alive:**
   ```bash
   # /etc/ssh/sshd_config
   ClientAliveInterval 60
   ClientAliveCountMax 3
   ```

2. **Akku-Optimierung deaktivieren:**
   - MIUI: Akku → "Keine Beschränkungen"
   - Android: Einstellungen → Apps → Optimierung deaktivieren
   - iOS: Hintergrundaktualisierung aktivieren

## Eingabeprobleme

### Bestimmte Zeichen können nicht getippt werden

**Lösung:** Einstellungen → Tastaturtyp → Wechseln zu `visiblePassword`

Hinweis: CJK-Eingaben funktionieren nach dieser Änderung möglicherweise nicht mehr.

## App-Probleme

### App stürzt beim Start ab

**Symptome:** App öffnet sich nicht, schwarzer Bildschirm

**Ursachen:** Korrupte Einstellungen, insbesondere durch den JSON-Editor

**Lösungen:**

1. **App-Daten löschen:**
   - Android: Einstellungen → Apps → ServerBox → Daten löschen
   - iOS: Löschen und neu installieren

2. **Backup wiederherstellen:** Importieren Sie ein Backup, das vor der Änderung der Einstellungen erstellt wurde

### Probleme beim Sichern/Wiederherstellen

**Backup funktioniert nicht:**
- Speicherplatz prüfen
- Sicherstellen, dass die App Speicherberechtigungen hat
- Anderen Speicherort versuchen

**Wiederherstellung schlägt fehl:**
- Integrität der Backup-Datei prüfen
- Kompatibilität der App-Version prüfen

## Widget-Probleme

### Widget aktualisiert nicht

**iOS:**
- Bis zu 30 Minuten auf automatische Aktualisierung warten
- Widget entfernen und neu hinzufügen
- Prüfen, ob die URL auf `/status` endet

**Android:**
- Auf das Widget tippen, um die Aktualisierung zu erzwingen
- Sicherstellen, dass die Widget-ID mit der Konfiguration in den App-Einstellungen übereinstimmt

**watchOS:**
- Watch-App neu starten
- Nach Konfigurationsänderung einige Minuten warten
- URL-Format prüfen

### Widget zeigt Fehler

- Sicherstellen, dass der ServerBox Monitor auf dem Server läuft
- URL im Browser testen
- Authentifizierungsdaten prüfen

## Leistungsprobleme

### App ist langsam

**Lösungen:**
- Aktualisierungsrate in den Einstellungen reduzieren
- Netzwerkgeschwindigkeit prüfen
- Nicht verwendete Server deaktivieren

### Hoher Akkuverbrauch

**Lösungen:**
- Aktualisierungsintervalle vergrößern
- Hintergrundaktualisierung deaktivieren
- Nicht verwendete SSH-Sitzungen schließen

## Hilfe erhalten

Wenn die Probleme weiterhin bestehen:

1. **GitHub Issues durchsuchen:** https://github.com/lollipopkit/flutter_server_box/issues
2. **Neues Issue erstellen:** App-Version, Plattform und Schritte zur Reproduktion angeben
3. **Wiki prüfen:** Diese Dokumentation und das GitHub Wiki
