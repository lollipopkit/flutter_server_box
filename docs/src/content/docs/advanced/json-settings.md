---
title: JSON Settings Editor
description: Access hidden settings via JSON editor
---

Some settings are hidden from the UI but can be accessed via JSON editor for advanced customization.

## Accessing JSON Editor

1. Open the app
2. Long press on **Settings** item in drawer
3. JSON editor opens

## Why Hidden Settings?

- Keep main settings UI simple
- Provide advanced options for power users
- Allow experimental features
- Enable debugging options

## Important Warnings

⚠️ **Before editing:**
- **Create a backup** - Wrong settings can cause app to not open
- **Note current values** - In case you need to revert
- **Edit carefully** - JSON syntax must be valid
- **Test incrementally** - Change one setting at a time

## Common Hidden Settings

### serverTabUseOldUI

Use old server tab UI.

```json
{
  "serverTabUseOldUI": true
}
```

**Type:** boolean
**Default:** false

### timeout

Connection timeout in seconds.

```json
{
  "timeout": 10
}
```

**Type:** integer
**Default:** 5
**Range:** 1-60

### recordHistory

Save history (SFTP paths, etc.).

```json
{
  "recordHistory": true
}
```

**Type:** boolean
**Default:** true

### textFactor

Text scaling factor.

```json
{
  "textFactor": 1.2
}
```

**Type:** double
**Default:** 1.0 (100%)
**Range:** 0.8-1.5

## Finding Available Settings

All settings are defined in [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart).

Look for lines like:

```dart
late final settingName = StoreProperty(
  box,
  'settingKey',
  defaultValue,
);
```

## How to Add a Setting

### Example: Enable Old UI

1. Find setting in source code:
   ```dart
   late final serverTabUseOldUI = StoreProperty(
     box,
     'serverTabUseOldUI',
     false,
   );
   ```

2. Note the details:
   - Name: `serverTabUseOldUI`
   - Type: `bool`
   - Default: `false`

3. Add to JSON editor:
   ```json
   {
     "serverTabUseOldUI": true
   }
   ```

4. Save and wait for app to reload

## Type Examples

### Boolean

```json
{
  "settingName": true
}
```

### Integer

```json
{
  "settingName": 42
}
```

### Double

```json
{
  "settingName": 1.5
}
```

### String

```json
{
  "settingName": "value"
}
```

### List

```json
{
  "settingName": ["item1", "item2"]
}
```

## Recovery

If app won't open after editing settings:

1. **Clear app data** (last resort)
2. **Reinstall app**
3. **Restore from backup**

## Best Practices

1. **Document changes** - Keep note of what you changed
2. **Test one at a time** - Don't change multiple settings
3. **Use valid JSON** - Verify syntax before saving
4. **Have backup ready** - Always backup before editing

## Experimental Settings

Some settings may be experimental and:
- May not work as expected
- Could change in future versions
- Might cause instability

Use with caution and report issues on GitHub.
