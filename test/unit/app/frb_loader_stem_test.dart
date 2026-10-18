import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/src/rust/frb_generated.dart';

void main() {
  test('the FRB loader stem is the cargo cdylib name', () {
    // flutter_rust_bridge_codegen 2.13 fills this from `cargo metadata`.
    // When that fails it writes UNKNOWN; Android then dlopens libUNKNOWN.so
    // and the app never starts.
    expect(RustLib.kDefaultExternalLibraryLoaderConfig.stem, 'sbm_ffi');
  });
}
