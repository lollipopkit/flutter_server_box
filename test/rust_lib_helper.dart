// Load the sbm_ffi native library in the test environment (run cargo build -p sbm_ffi first)
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:server_box/src/rust/frb_generated.dart';

Future<void> initRustLibForTest() async {
  if (RustLib.instance.initialized) return;
  // Platform-specific cdylib artifact names (Windows has no `lib` prefix)
  final candidates = [
    if (Platform.isMacOS) 'target/debug/libsbm_ffi.dylib',
    if (Platform.isWindows) 'target/debug/sbm_ffi.dll',
    if (Platform.isLinux) 'target/debug/libsbm_ffi.so',
  ];
  final lib = candidates.firstWhere(
    (p) => File(p).existsSync(),
    orElse: () => throw StateError(
      'sbm_ffi native library not found (tried: $candidates); '
      'run `cargo build -p sbm_ffi` first',
    ),
  );
  await RustLib.init(externalLibrary: ExternalLibrary.open(lib));
}
