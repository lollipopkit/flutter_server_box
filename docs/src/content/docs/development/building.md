---
title: Building
description: Build Server Box and Monitor agent for different platforms
---

Server Box uses the custom `fl_build` tool to build the App for each platform. Monitor agent is an independent Rust service with its own build process.

## Prerequisites

- Flutter SDK (stable channel)
- Platform tools: Xcode for iOS, Android Studio and Android SDK for Android, and Visual Studio for Windows
- Rust toolchain: the App builds `crates/sbm_ffi` through a Dart build hook, `flutter_rust_bridge_hooks`, and native assets

Initialize the repository's Git submodules before fetching Dart dependencies:

```bash
git submodule update --init --recursive
```

## Development build

```bash
# Run the App
flutter run

# Run on a specific device
flutter run -d <device-id>
```

## Release build

Build a target platform with `fl_build`:

```bash
dart run fl_build -p <platform>
```

Available platforms are `ios`, `android`, `macos`, `linux`, and `windows`.

## Platform requirements

### iOS

```bash
dart run fl_build -p ios
```

Requires macOS with Xcode and an Apple Developer account for signing.

### Android

```bash
dart run fl_build -p android
```

Requires the Android SDK, a JDK, and a keystore for release signing. Formal release builds must use the release keystore configured in `key.properties`. For local verification only, explicitly pass `-PallowDebugReleaseSigning=true` to use debug signing.

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

Requires a Windows build environment with Visual Studio.

## Build Monitor agent

Monitor agent is a standalone server binary and is not part of the App build process.

```bash
# From the repository root
cargo build --release

# Build the web panel
cd monitor/frontend
npm install
npm run build
```

After the build, the agent serves the panel when `frontend/dist` exists. From the repository root, `make monitor-dev` starts the development environment: the API listens on `:3770` and the Vite dev server on `:3000`.

Release artifacts are built by the `monitor-release.yml` workflow. It supports `workflow_dispatch` only; `monitor-v*` tags are independent of App releases. See `monitor/Dockerfile` for Docker builds.

## Build hooks

`fl_build` regenerates `lib/data/res/build_data.dart` on every build, derives the build number from Git history, and writes the version into Xcode configuration. The `fl_build:` section in `pubspec.yaml` configures the App name.

## Troubleshooting

### Clean build

```bash
flutter clean
dart run build_runner build --delete-conflicting-outputs
flutter pub get
```

`flutter clean` removes `build/`, including the iOS Linux engine libraries when that engine is enabled. Rebuild the required target with `scripts/build-ish-ios.sh device`, `simulator`, or `macos`; otherwise the linker will report missing engine files.

### Dependency version conflict

Resolve dependencies only after checking compatibility:

```bash
flutter pub upgrade
```

After changing an annotated model, run code generation as well; see [Code Generation](/docs/development/codegen/).

## Release checklist

1. Update the version in `pubspec.yaml`.
2. Run code generation and localization generation.
3. Run Dart, Flutter, and Rust tests.
4. Build every target platform.
5. Verify key features on real devices.
6. Create the GitHub release.
