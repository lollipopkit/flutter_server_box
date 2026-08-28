---
title: Hidden Settings (JSON)
description: Access advanced settings through the JSON editor
---

Some advanced settings do not have a dedicated UI control, but can be edited through the JSON editor.

## Open the JSON editor

Go to **Settings → App → General → More** and tap **(Dev) Edit raw json**.

## Common settings

### `timeOut`

Connection timeout in seconds.

```json
{"timeOut": 10}
```

**Type:** integer　**Default:** `5`

The value is stored as JSON and used as seconds by the connection code. Set a reasonable positive value.

### `recordHistory`

Whether to save history such as SFTP paths.

```json
{"recordHistory": true}
```

**Type:** boolean　**Default:** `true`

### `textFactor`

UI text scaling factor.

```json
{"textFactor": 1.2}
```

**Type:** number　**Default:** `1.0`

Extreme values can make parts of the interface unusable.

## Find other settings

All settings are defined in [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart).

Look for definitions similar to:

```dart
late final settingName = propertyDefault('settingKey', defaultValue);
```

Use the setting key and default value from the current source. Confirm that the setting still exists in the version you are using before editing it.

## Before editing

- **Create a backup first.** An invalid setting can prevent the App from starting.
- **Keep the JSON valid.** Check quotes, commas, brackets, and value types.
- **Change one setting at a time.** Test the result before making another change.
- **Do not add credentials.** Passwords, tokens, and private keys should not be entered through the settings JSON.

## Recovery

If the App cannot start after an edit:

1. Restore the backup created before the change if possible.
2. Android: clear Server Box app data in system settings.
3. iOS: delete and reinstall the App.
4. Open the App and restore the backup.

Clearing app data or reinstalling deletes data that was not backed up. Use these steps only as a last resort.
