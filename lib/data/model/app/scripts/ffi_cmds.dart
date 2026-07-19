import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/src/rust/api/parser.dart' as ffi;

/// Single source of truth for collection commands: the shared Rust library's
/// manifest (crates/sbm_parser/src/commands.rs, see doc/adr/0001).
/// Falls back to the enum's built-in commands when the FFI is uninitialized
/// (e.g. some unit tests).
abstract final class FfiCmds {
  static final _cache = <CmdTypeSys, Map<String, String>>{};

  static String? lookup(CmdTypeSys sysType, String key) {
    try {
      final map = _cache.putIfAbsent(sysType, () {
        final system = switch (sysType) {
          CmdTypeSys.linux => 'linux',
          CmdTypeSys.bsd => 'bsd',
          CmdTypeSys.windows => 'windows',
        };
        return {
          for (final spec in ffi.commandSpecs(system: system)) spec.key: spec.cmd,
        };
      });
      return map[key];
    } catch (e) {
      Loggers.app.warning('FfiCmds.lookup($sysType, $key) fallback', e);
      return null;
    }
  }
}
