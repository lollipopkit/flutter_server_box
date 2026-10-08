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
/// Theme packages are read in Rust (fl_lib's `rust/`): the library cargo built
/// is loaded here, so `cargo build --manifest-path packages/fl_lib/rust/Cargo.toml
/// -p fl_lib_ffi` comes first, as `cargo build -p sbm_ffi` does for the FFI
/// tests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  initThemeHost();
  const dir = 'packages/fl_lib/rust/target/debug';
  final library = [
    if (Platform.isMacOS) '$dir/libfl_lib_ffi.dylib',
    if (Platform.isLinux) '$dir/libfl_lib_ffi.so',
    if (Platform.isWindows) '$dir/fl_lib_ffi.dll',
  ].firstWhere(
    (path) => File(path).existsSync(),
    orElse: () => throw StateError(
      'fl_lib_ffi not built: run `cargo build --manifest-path '
      'packages/fl_lib/rust/Cargo.toml -p fl_lib_ffi` first',
    ),
  );
  await ThemeRust.ensureInitialized(library: ExternalLibrary.open(library));
  await testMain();
}
