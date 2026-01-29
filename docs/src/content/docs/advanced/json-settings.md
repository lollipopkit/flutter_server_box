---
title: Hidden Settings (JSON)
description: Access advanced settings via JSON editor
---

Some settings are hidden from the UI but accessible via JSON editor.

## Access

Long-press **Settings** in drawer to open JSON editor.

## Common Hidden Settings

### serverTabUseOldUI

Use old server tab UI.

```json
{"serverTabUseOldUI": true}
```

**Type:** boolean | **Default:** false

### timeout

Connection timeout in seconds.

```json
{"timeout": 10}
```

**Type:** integer | **Default:** 5 | **Range:** 1-60

### recordHistory

Save history (SFTP paths, etc.).

```json
{"recordHistory": true}
```

**Type:** boolean | **Default:** true

### textFactor

Text scaling factor.

```json
{"textFactor": 1.2}
```

**Type:** double | **Default:** 1.0 | **Range:** 0.8-1.5

## Finding More Settings

All settings defined in [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart).

Look for:
```dart
late final settingName = StoreProperty(box, 'settingKey', defaultValue);
```

## ⚠️ Important

**Before editing:**
- **Create backup** - Wrong settings can cause app to not open
- **Edit carefully** - JSON must be valid
- **Change one at a time** - Test each setting

## Recovery

If app won't open after editing:
1. Clear app data (last resort)
2. Reinstall app
3. Restore from backup
