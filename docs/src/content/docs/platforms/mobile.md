---
title: Mobile Features
description: Platform-specific features for iOS and Android
---

Server Box provides biometrics, home screen widgets, background running, and a virtual keyboard on iOS and Android.

## Biometrics

Use device biometrics to unlock the App:

- **iOS**: Face ID or Touch ID
- **Android**: A biometric method supported by the device, such as fingerprint authentication

Enable it at **Settings → App → General → Biometric authentication**. If no biometrics are enrolled, the App tells you to enroll one first instead of showing a switch that cannot work.

## Home screen widgets

Widgets require [Monitor agent](/docs/advanced/monitor-agent/) on the server. After installing the agent, configure the server in the App. The widget reads the server list published by the App; you do not enter a URL in the widget.

The iOS widget requires iOS 17 or later. This does not change the minimum iOS version of the App.

### iOS

1. Long-press the Home Screen and tap **+**.
2. Search for “Server Box”.
3. Choose the **Small** or **Medium** widget.
4. After adding it, long-press the widget and tap **Edit Widget**.
5. Select the server to display.

Small widgets show current readings. Medium widgets show charts for multiple metrics. Each widget selects one server.

### Android

1. Long-press the Home Screen and tap **Widgets**.
2. Find “Server Box”, choose the Small or Medium type, and add it.
3. On the configuration page, select a server and the leading metric.
4. Tap Save.
5. Tap the widget to refresh it manually when needed.

## Android background running

To keep SSH connections alive after the App moves to the background:

1. Enable **Settings → App → General → Android Setting → Background running**.
2. Allow Server Box to send notifications in the system settings.
3. Disable battery optimization as required by your device. MIUI/HyperOS may also require the battery policy to be set to “No restrictions”.

Background connections use a persistent notification. Without notification permission, Android cannot run the required foreground service, so connections may stop in the background.

## iOS background behavior

iOS limits background execution. Connections may be suspended, then reconnect when you return to the App. Whether background refresh runs promptly is controlled by iOS.

## Push notifications

Server alerts are sent by [Monitor agent](/docs/advanced/monitor-agent/) running on the server. Configure alert rules and push channels on the Monitor side.

## Mobile UI features

- **Pull to refresh**: Fetch the latest server status
- **Landscape mode**: Provide more horizontal space for the terminal
- **Virtual keyboard**: Provide Esc, Tab, Ctrl/Alt, and other terminal keys

## File integration

- **Document picker**: Select local files for SFTP uploads and backup import/export
- **Share**: Export files to another App
