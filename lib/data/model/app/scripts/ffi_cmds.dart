import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/src/rust/api/parser.dart' as ffi;

/// 采集命令的单一事实来源:共享 Rust 库的命令清单
/// (crates/sbm_parser/src/commands.rs,见 doc/adr/0001)。
/// FFI 未初始化时(如部分单测)回退到枚举内置命令。
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
