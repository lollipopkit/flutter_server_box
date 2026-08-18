---
title: Mobile Features
description: iOS and Android specific features
---

Server Box provides several mobile-specific features for iOS and Android devices.

## Biometric Authentication

Secure your servers with biometric authentication:

- **iOS**: Face ID or Touch ID
- **Android**: Fingerprint authentication

Enable in Settings → **App** → Setting → **Biometric authentication**. The entry
says so when the device has none enrolled, instead of offering a switch that
could not work.

## Home Screen Widgets

Add server status widgets to your home screen for quick monitoring.

### iOS

- Long press on home screen
- Tap **+** to add widget
- Search for "Server Box"
- Choose widget size:
  - Small: Single server status
  - Medium: Multiple servers
  - Large: Detailed info

### Android

- Long press on home screen
- Tap **Widgets**
- Find "Server Box"
- Select widget type

## Background Running

### Android

Keep connections alive in the background:

- Enable in Settings → **App** → Setting → **Android Setting** → **Background running**
- Requires battery optimization exclusion
- Persistent notifications for active connections

### iOS

Background limitations apply:

- Connections may pause in background
- Quick reconnect on return to app
- Background refresh support

## Push Notifications

Server alerts (offline, threshold exceeded) are pushed by a
[monitor agent](/docs/advanced/monitor-agent/) running on your servers —
configure alert rules and push channels there.

## Mobile UI Features

- **Pull to Refresh**: Update server status
- **Landscape Mode**: Better terminal experience
- **Virtual Keyboard**: Terminal shortcuts

## File Integration

- **Document Picker**: Pick local files for SFTP upload and backup import/export
- **Share**: Export files to other apps
