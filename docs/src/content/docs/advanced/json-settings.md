---
title: Hidden Settings (JSON)
description: Access advanced settings via JSON editor
---

Some settings are not exposed in the UI but can be edited in the JSON editor.

## Access

Long-press **Settings** in drawer to open JSON editor.

## Common Hidden Settings

### timeOut

Connection timeout in seconds.

```json
{"timeOut": 10}
```

**Type:** integer | **Default:** 5. The setting is stored as JSON; keep the value
reasonable because connection code uses it as a timeout in seconds.

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

**Type:** number | **Default:** 1.0. The setting is stored as JSON; extreme
values may make the interface unusable.

## Finding More Settings

All settings defined in [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart).

Look for:
```dart
late final settingName = propertyDefault('settingKey', defaultValue);
```

## ⚠️ Important

**Before editing:**
- **Create a backup**. Invalid settings can prevent the app from starting.
- **Edit carefully**. The JSON must remain valid.
- **Change one setting at a time**. Test each change.

## Recovery

If the app does not start after an edit:
1. Clear app data (last resort)
2. Reinstall app
3. Restore from backup
