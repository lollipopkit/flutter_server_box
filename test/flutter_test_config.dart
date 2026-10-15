import 'dart:async';
import 'dart:io';

import 'package:fl_lib/theme.dart';
import 'package:fl_pi_llm/fl_pi_llm.dart';
import 'package:server_box/core/service/theme_host.dart';

/// Runs before every test file.
///
/// The shared theme code reads the app's settings through a host set once at
/// launch; the app does it in `main`, and this is the tests' launch. The store
/// it reads is resolved per call, so each test's own store is the one read.
///
/// fl_lib reads themes in Rust and fl_pi_llm reads skills in Rust; the app
/// loads both at launch. Here they are the libraries the build hooks put under
/// `build/native_assets`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  initThemeHost();
  if (_nativeAsset('fl_lib_ffi') case final lib?) {
    await ThemeRust.ensureInitialized(library: lib);
  }
  if (_nativeAsset('fl_pi_llm') case final lib?) {
    await FlPiLlm.loadLibrary(externalLibrary: lib);
  }
  await testMain();
}

ExternalLibrary? _nativeAsset(String name) {
  final file = File(switch (Platform.operatingSystem) {
    'macos' => 'build/native_assets/macos/lib$name.dylib',
    'windows' => 'build/native_assets/windows/$name.dll',
    _ => 'build/native_assets/linux/lib$name.so',
  });
  return file.existsSync() ? ExternalLibrary.open(file.path) : null;
}
