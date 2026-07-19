// Load the sbm_ffi native library in the test environment (run cargo build -p sbm_ffi first)
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:server_box/src/rust/frb_generated.dart';

Future<void> initRustLibForTest() async {
  if (RustLib.instance.initialized) return;
  final lib = File('target/debug/libsbm_ffi.dylib').existsSync()
      ? 'target/debug/libsbm_ffi.dylib'
      : 'target/debug/libsbm_ffi.so';
  await RustLib.init(externalLibrary: ExternalLibrary.open(lib));
}
