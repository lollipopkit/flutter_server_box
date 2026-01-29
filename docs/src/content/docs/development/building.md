---
title: Building
description: Build instructions for different platforms
---

Flutter Server Box uses a custom build system (`fl_build`) for cross-platform builds.

## Prerequisites

- Flutter SDK (stable channel)
- Platform-specific tools (Xcode for iOS, Android Studio for Android)
- Rust toolchain (for some native dependencies)

## Development Build

```bash
# Run in development mode
flutter run

# Run on specific device
flutter run -d <device-id>
```

## Production Build

The project uses `fl_build` for building:

```bash
# Build for specific platform
dart run fl_build -p <platform>

# Available platforms:
# - ios
# - android
# - macos
# - linux
# - windows
```

## Platform-Specific Builds

### iOS

```bash
dart run fl_build -p ios
```

Requires:
- macOS with Xcode
- CocoaPods
- Apple Developer account for signing

### Android

```bash
dart run fl_build -p android
```

Requires:
- Android SDK
- Java Development Kit
- Keystore for signing

### macOS

```bash
dart run fl_build -p macos
```

### Linux

```bash
dart run fl_build -p linux
```

### Windows

```bash
dart run fl_build -p windows
```

Requires Windows with Visual Studio.

## Pre/Post Build

The `make.dart` script handles:

- Metadata generation
- Version string updates
- Platform-specific configurations

## Troubleshooting

### Clean Build

```bash
flutter clean
dart run build_runner build --delete-conflicting-outputs
flutter pub get
```

### Version Mismatch

Ensure all dependencies are compatible:
```bash
flutter pub upgrade
```

## Release Checklist

1. Update version in `pubspec.yaml`
2. Run code generation
3. Run tests
4. Build for all target platforms
5. Test on physical devices
6. Create GitHub release
