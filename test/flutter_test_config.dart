import 'dart:async';
import 'dart:io';

import 'package:fl_lib/theme.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:server_box/core/service/theme_host.dart';

/// Runs before every test file.
///
/// The shared theme code reads the app's settings through a host set once at
/// launch; the app does it in `main`, and this is the tests' launch. The store
/// it reads is resolved per call, so each test's own store is the one read.
///
/// Themes are read in fl_lib's Rust, which the app loads at launch through
/// `ThemePackages.prepareSelectedTheme`. Here it is the library the build hook
/// put under `build/native_assets`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  initThemeHost();
  final library = File(switch (Platform.operatingSystem) {
    'macos' => 'build/native_assets/macos/libfl_lib_ffi.dylib',
    'windows' => r'build\native_assets\windows\fl_lib_ffi.dll',
    _ => 'build/native_assets/linux/libfl_lib_ffi.so',
  });
  if (library.existsSync()) {
    await ThemeRust.ensureInitialized(
      library: ExternalLibrary.open(library.path),
    );
  }
  await testMain();
}
