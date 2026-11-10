// Load the sbm_ffi native library in the test environment.
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:server_box/src/rust/frb_generated.dart';

Future<void> initRustLibForTest() async {
  if (RustLib.instance.initialized) return;
  await RustLib.init(externalLibrary: ExternalLibrary.open(rustLibPathForTest()));
}

/// The sbm_ffi library on this platform — for a test that loads it somewhere
/// [initRustLibForTest] does not, another isolate.
///
/// The one `flutter test` builds through `hook/build.dart` before any test
/// runs, which is current with the crates by construction; `cargo build -p
/// sbm_ffi`'s for a test run some other way.
String rustLibPathForTest() {
  // Platform-specific cdylib artifact names (Windows has no `lib` prefix)
  final candidates = [
    if (Platform.isMacOS) ...[
      'build/native_assets/macos/libsbm_ffi.dylib',
      'target/debug/libsbm_ffi.dylib',
    ],
    if (Platform.isWindows) ...[
      'build/native_assets/windows/sbm_ffi.dll',
      'target/debug/sbm_ffi.dll',
    ],
    if (Platform.isLinux) ...[
      'build/native_assets/linux/libsbm_ffi.so',
      'target/debug/libsbm_ffi.so',
    ],
  ];
  return candidates.firstWhere(
    (p) => File(p).existsSync(),
    orElse: () => throw StateError(
      'sbm_ffi native library not found (tried: $candidates); '
      'run `flutter test`, which builds it, or `cargo build -p sbm_ffi`',
    ),
  );
}
