---
title: Versteckte Einstellungen (JSON)
description: Zugriff auf erweiterte Einstellungen über den JSON-Editor
---

Einige Einstellungen sind in der Benutzeroberfläche ausgeblendet, aber über den JSON-Editor zugänglich.

## Zugriff

Halten Sie **Einstellungen** in der Seitenleiste lange gedrückt, um den JSON-Editor zu öffnen.

## Gängige versteckte Einstellungen

### serverTabUseOldUI

Verwenden Sie die alte Benutzeroberfläche für den Server-Tab.

```json
{"serverTabUseOldUI": true}
```

**Typ:** Boolean | **Standard:** false

### timeout

Verbindungs-Timeout in Sekunden.

```json
{"timeout": 10}
```

**Typ:** Integer | **Standard:** 5 | **Bereich:** 1-60

### recordHistory

Verlauf speichern (SFTP-Pfade, usw.).

```json
{"recordHistory": true}
```

**Typ:** Boolean | **Standard:** true

### textFactor

Textskalierungsfaktor.

```json
{"textFactor": 1.2}
```

**Typ:** Double | **Standard:** 1.0 | **Bereich:** 0.8-1.5

## Weitere Einstellungen finden

Alle Einstellungen sind in [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart) definiert.

Suchen Sie nach:
```dart
late final settingName = StoreProperty(box, 'settingKey', defaultValue);
```

## ⚠️ Wichtig

**Vor dem Bearbeiten:**
- **Backup erstellen** - Falsche Einstellungen können dazu führen, dass die App nicht mehr öffnet
- **Sorgfältig bearbeiten** - JSON muss gültig sein
- **Nur eins nach dem anderen ändern** - Testen Sie jede Einstellung

## Wiederherstellung

Wenn die App nach dem Bearbeiten nicht mehr öffnet:
1. App-Daten löschen (letzter Ausweg)
2. App neu installieren
3. Aus Backup wiederherstellen
