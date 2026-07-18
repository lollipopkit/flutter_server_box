// 测试环境加载 sbm_ffi 原生库(运行前需 cargo build -p sbm_ffi)
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
