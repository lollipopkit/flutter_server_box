# F-Droid release recipe

The canonical metadata lives in
[`fdroiddata/metadata/tech.lolli.toolbox.yml`](https://gitlab.com/fdroid/fdroiddata/-/blob/master/metadata/tech.lolli.toolbox.yml),
not in this repository. It currently stops at v1.0.1466. Submit an fdroiddata
update only after the next `v1.0.<build>` tag and its GitHub release APKs
exist; before that, neither the immutable commit nor the reference binaries
can be named.

## Pinned inputs

- Flutter is read from `.github/actions/setup-flutter/action.yml`. Do not copy
  the version into F-Droid metadata without checking that file.
- Android NDK r28c is pinned as `28.2.13676358` in
  `android/ndk-version.txt`.
- Android compile SDK 36 and SDK Build Tools 35.0.0 are pinned in
  `android/compile-sdk-version.txt` and `android/build-tools-version.txt`.
- The app's Rust native asset pins its compiler and targets in
  `crates/sbm_ffi/rust-toolchain.toml`.
- `pubspec.lock`, `Cargo.lock`, Gradle's wrapper, every git dependency, and all
  submodules must remain locked at the release commit.
- proot and talloc are fetched, authenticated, and built by
  `scripts/build-proot-android.sh` during `prebuild`.

`scripts/release/prepare-fdroid.sh` is the only networked preparation entry
point. It fills the Pub, Cargo, Rust, Gradle, proot, and talloc inputs.
`FDROID_OFFLINE=true scripts/release/build-fdroid.sh <abi>` then refuses
network fallback for those build systems and produces an unsigned split APK.

## ABI and version-code mapping

| F-Droid build argument | Flutter target | APK filename | versionCode |
| --- | --- | --- | --- |
| `amd64` | `android-x64` | `app-x86_64-release-unsigned.apk` | `<build>01` |
| `arm` | `android-arm` | `app-armeabi-v7a-release-unsigned.apk` | `<build>02` |
| `arm64` | `android-arm64` | `app-arm64-v8a-release-unsigned.apk` | `<build>03` |

The output directory is `build/app/outputs/apk/release/`. Flutter also copies
the same APKs to `build/app/outputs/flutter-apk/`, but drops `-unsigned` from
their filenames; the recipe deliberately uses Gradle's unambiguously named
originals. These codes match
`android/app/build.gradle` and the existing `VercodeOperation` entries in
fdroiddata.

## Metadata template for the next tag

Replace every `<build>` with the numeric suffix of the final tag and every
`<commit>` with that tag's full commit SHA. Add all three records to the
existing metadata file. Keep `binary:` enabled: it is the F-Droid check that
the unsigned rebuild differs from the published APK only by the allowed
signature.

```yaml
  - versionName: 1.0.<build>
    versionCode: <build>01
    commit: <commit>
    submodules: true
    sudo:
      - apt-get update
      - apt-get install -y zip unzip make
    output: build/app/outputs/apk/release/app-x86_64-release-unsigned.apk
    binary:
      https://github.com/lollipopkit/flutter_server_box/releases/download/v%v/ServerBox_v%v_amd64.apk
    srclibs:
      - flutter@stable
    rm:
      - ios
      - linux
      - macos
      - test
      - windows
    prebuild:
      - flutterVersion=$(sed -n -E 's/^[[:space:]]*flutter-version:[[:space:]]*([^[:space:]]+).*/\1/p'
        .github/actions/setup-flutter/action.yml)
      - '[[ $flutterVersion ]]'
      - git -C $$flutter$$ checkout -f $flutterVersion
      - export PATH=$$flutter$$/bin:$PATH
      - flutter config --no-analytics
      - scripts/release/prepare-fdroid.sh
    scandelete:
      - packages/xterm/example/assets/specs_v1.json.gz
    build:
      - export PATH=$$flutter$$/bin:$PATH
      - FDROID_OFFLINE=true scripts/release/build-fdroid.sh amd64
    target: android-36
    ndk: r28c

  - versionName: 1.0.<build>
    versionCode: <build>02
    commit: <commit>
    submodules: true
    sudo:
      - apt-get update
      - apt-get install -y zip unzip make
    output: build/app/outputs/apk/release/app-armeabi-v7a-release-unsigned.apk
    binary:
      https://github.com/lollipopkit/flutter_server_box/releases/download/v%v/ServerBox_v%v_arm.apk
    srclibs:
      - flutter@stable
    rm:
      - ios
      - linux
      - macos
      - test
      - windows
    prebuild:
      - flutterVersion=$(sed -n -E 's/^[[:space:]]*flutter-version:[[:space:]]*([^[:space:]]+).*/\1/p'
        .github/actions/setup-flutter/action.yml)
      - '[[ $flutterVersion ]]'
      - git -C $$flutter$$ checkout -f $flutterVersion
      - export PATH=$$flutter$$/bin:$PATH
      - flutter config --no-analytics
      - scripts/release/prepare-fdroid.sh
    scandelete:
      - packages/xterm/example/assets/specs_v1.json.gz
    build:
      - export PATH=$$flutter$$/bin:$PATH
      - FDROID_OFFLINE=true scripts/release/build-fdroid.sh arm
    target: android-36
    ndk: r28c

  - versionName: 1.0.<build>
    versionCode: <build>03
    commit: <commit>
    submodules: true
    sudo:
      - apt-get update
      - apt-get install -y zip unzip make
    output: build/app/outputs/apk/release/app-arm64-v8a-release-unsigned.apk
    binary:
      https://github.com/lollipopkit/flutter_server_box/releases/download/v%v/ServerBox_v%v_arm64.apk
    srclibs:
      - flutter@stable
    rm:
      - ios
      - linux
      - macos
      - test
      - windows
    prebuild:
      - flutterVersion=$(sed -n -E 's/^[[:space:]]*flutter-version:[[:space:]]*([^[:space:]]+).*/\1/p'
        .github/actions/setup-flutter/action.yml)
      - '[[ $flutterVersion ]]'
      - git -C $$flutter$$ checkout -f $flutterVersion
      - export PATH=$$flutter$$/bin:$PATH
      - flutter config --no-analytics
      - scripts/release/prepare-fdroid.sh
    scandelete:
      - packages/xterm/example/assets/specs_v1.json.gz
    build:
      - export PATH=$$flutter$$/bin:$PATH
      - FDROID_OFFLINE=true scripts/release/build-fdroid.sh arm64
    target: android-36
    ndk: r28c
```

Before opening the fdroiddata PR, run the tag-triggered
`Android reproducible build` workflow successfully and confirm that all three
GitHub release APK names above exist. F-Droid's `binary:` comparison remains
the final cross-environment reproducibility verdict.
