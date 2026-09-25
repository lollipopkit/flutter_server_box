---
title: Building
description: Build Server Box and Monitor agent for different platforms
---

Build the Flutter App with the repository's `fl_build` tool. Monitor agent is
a separate Rust service and has its own build steps.

## Prerequisites

- Flutter SDK on the stable channel
- Platform SDKs: Xcode for iOS, Android Studio and Android SDK for Android, or Visual Studio for Windows
- Rust toolchain: the App builds `crates/sbm_ffi` using a Dart build hook, `flutter_rust_bridge_hooks`, and native assets

Initialize the Git submodules before fetching Dart packages:

```bash
git submodule update --init --recursive
```

## Run a development build

```bash
# Run on the default device
flutter run

# Select a device explicitly
flutter run -d <device-id>
```

## Release build

Pass the target platform to `fl_build`:

```bash
dart run fl_build -p <platform>
```

Supported platform names are `ios`, `android`, `macos`, `linux`, and
`windows`.

## Platform requirements

### iOS

```bash
dart run fl_build -p ios
```

Builds require macOS and Xcode. Signing also requires an Apple Developer
account.

### Android

```bash
dart run fl_build -p android
```

Requires the Android SDK, a JDK, and a keystore for release signing. Release
builds must use the keystore configured in `key.properties`. For local
verification only, pass `-PallowDebugReleaseSigning=true` explicitly to use
debug signing. Reproducible and F-Droid builds use
`-PallowUnsignedRelease=true`, which omits signing configuration;
`scripts/release/android-build-env.sh` exports this option.

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

Requires Visual Studio with the **Desktop development with C++** workload and
ATL support.

## Build Monitor agent

Monitor agent is a standalone server binary. Build it separately from the
Flutter App:

```bash
# From the repository root
cargo build --release

# Build the web panel
cd monitor/frontend
npm install
npm run build
```

After building the panel, Monitor agent serves it when `frontend/dist` exists.
For development, run `make monitor-dev` from the repository root. It starts
the API on `:3770` and the Vite dev server on `:3000`.

The `monitor-release.yml` workflow builds release artifacts and currently
runs only through `workflow_dispatch`. Monitor `monitor-v*` tags are separate
from App releases. For a Docker build, see `monitor/Dockerfile`.

## Build hooks

On every build, `fl_build` regenerates `lib/data/res/build_data.dart`, derives
the build number from Git history, and writes the version to the Xcode
configuration. Set the App name in the `fl_build:` section of `pubspec.yaml`.

## Troubleshooting

### Clean build

```bash
flutter clean
flutter pub get
dart run build_runner build
```

`flutter clean` removes `build/`, including the iOS Linux engine libraries
when that engine is enabled. Rebuild the required target with
`scripts/build-ish-ios.sh device`, `simulator`, or `macos`; otherwise linking
will fail because those engine files are missing.

### Dependency version conflict

Check package compatibility before upgrading dependencies:

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
