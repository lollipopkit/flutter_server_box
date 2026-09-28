---
title: Hidden Settings (JSON)
description: Access advanced settings through the JSON editor
---

The JSON editor exposes advanced settings that do not have a dedicated control
in the interface. Change a value only when you understand what it affects.

## Open the JSON editor

Open **Settings → App → General → More**, then select **(Dev) Edit raw json**.

## Common settings

### `timeOut`

Maximum time to wait for a connection, in seconds.

```json
{"timeOut": 10}
```

**Type:** integer　**Default:** `5`

This integer is interpreted as seconds. Use a positive value appropriate for
your network.

### `recordHistory`

Whether the App saves recent items such as SFTP paths.

```json
{"recordHistory": true}
```

**Type:** boolean　**Default:** `true`

### `textFactor`

Scale factor for text in the interface.

```json
{"textFactor": 1.2}
```

**Type:** number　**Default:** `1.0`

Extreme values can make parts of the interface unusable.

## Find other settings

The setting keys and their defaults are declared in
[`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart).

Search for declarations in this form:

```dart
late final settingName = propertyDefault('settingKey', defaultValue);
```

Use the key and default from the source for your App version. Settings can
change between releases, so confirm that a key still exists before editing it.

## Before editing

- **Back up your data first.** A malformed or unsupported value can stop the
  App from starting.
- **Keep the document valid JSON.** Check quotation marks, commas, brackets,
  and the expected value type.
- **Edit one key at a time.** Reopen the App and check the affected feature
  before changing another value.
- **Keep credentials out of this editor.** Do not enter passwords, tokens, or
  private keys in the settings JSON.

## Recovery

If an edit prevents the App from starting, try these recovery options in
order:

1. Restore the backup created before the change if possible.
2. Android: clear Server Box app data in system settings.
3. iOS: delete and reinstall the App.
4. Open the App and restore the backup.

Clearing app data or reinstalling removes anything that has not been backed
up. Use those options only if you cannot restore the App another way.
