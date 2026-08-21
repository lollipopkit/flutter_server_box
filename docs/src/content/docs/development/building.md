---
title: Building
description: Build instructions for different platforms
---

The project uses `fl_build` to build the supported platforms.

## Prerequisites

- Flutter SDK (stable channel)
- Platform toolchains (Xcode for iOS, Android Studio for Android)
- Rust toolchain (required: the `crates/sbm_ffi` Rust crate is built into the app
  by the Dart build hook through `flutter_rust_bridge_hooks` and native assets)

Initialize the bundled Git submodules before fetching Dart dependencies:

```bash
git submodule update --init --recursive
```

## Development Build

```bash
# Run in development mode
flutter run

# Run on specific device
flutter run -d <device-id>
```

## Release Build

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

## Building the Monitor

The server-side monitor is a separate binary, built from `monitor/`. It is not
part of any app build.

```bash
cd monitor

# Backend
cargo build --release

# Panel, served by the agent itself when frontend/dist exists
cd frontend && npm install && npm run build
```

`make monitor-dev` from the repository root runs both in development mode: the
API on `:3770` and the panel's vite dev server on `:3000`.

Release artifacts come from the `monitor-release.yml` workflow, which is
`workflow_dispatch`-only and publishes `monitor-v*` tags separately from the
app's own releases. Docker is in `monitor/Dockerfile`.

## Pre/Post Build

The `make.dart` script handles:

- Metadata generation
- Version string updates
- Platform-specific configurations

## Troubleshooting

### Clean build

```bash
flutter clean
dart run build_runner build --delete-conflicting-outputs
flutter pub get
```

### Dependency version mismatch

If dependency resolution reports a version conflict, run:
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
